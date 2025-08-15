import json
import os
import boto3
import logging
from botocore.exceptions import ClientError, WaiterError
from typing import Dict, Any, Optional
import time

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients with error handling
try:
    rds_client = boto3.client('rds', region_name=os.environ.get('AWS_REGION'))
    secretsmanager_client = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION'))
    sns_client = boto3.client('sns', region_name=os.environ.get('AWS_REGION'))
except Exception as e:
    logger.error(f"Failed to initialize AWS clients: {e}")
    raise

def validate_environment() -> Dict[str, str]:
    """Validate and return required environment variables."""
    required_vars = {
        'AWS_REGION': os.environ.get('AWS_REGION'),
        'PRIMARY_HEALTH_ALARM_NAME': os.environ.get('PRIMARY_HEALTH_ALARM_NAME'),
        'DR_DB_REPLICA_ID': os.environ.get('DR_DB_REPLICA_ID'),
        'DR_DB_CREDENTIALS_SECRET_NAME': os.environ.get('DR_DB_CREDENTIALS_SECRET_NAME'),
        'NOTIFICATION_TOPIC_ARN': os.environ.get('NOTIFICATION_TOPIC_ARN')
    }
    
    missing_vars = [key for key, value in required_vars.items() if not value]
    if missing_vars:
        raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")
    
    return required_vars

def send_notification(topic_arn: str, subject: str, message: str) -> None:
    """Send SNS notification."""
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        logger.info(f"Notification sent: {subject}")
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")

def get_secret_value(secret_name: str) -> Dict[str, Any]:
    """Retrieve and parse secret from Secrets Manager."""
    try:
        response = secretsmanager_client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except ClientError as e:
        logger.error(f"Failed to retrieve secret {secret_name}: {e}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse secret JSON for {secret_name}: {e}")
        raise

def check_db_instance_state(db_instance_id: str) -> str:
    """Check the current state of the DB instance."""
    try:
        response = rds_client.describe_db_instances(DBInstanceIdentifier=db_instance_id)
        db_instance = response['DBInstances'][0]
        return db_instance['DBInstanceStatus']
    except ClientError as e:
        logger.error(f"Failed to describe DB instance {db_instance_id}: {e}")
        raise

def is_read_replica(db_instance_id: str) -> bool:
    """Check if the DB instance is still a read replica."""
    try:
        response = rds_client.describe_db_instances(DBInstanceIdentifier=db_instance_id)
        db_instance = response['DBInstances'][0]
        return 'ReadReplicaSourceDBInstanceIdentifier' in db_instance and db_instance['ReadReplicaSourceDBInstanceIdentifier'] is not None
    except ClientError as e:
        logger.error(f"Failed to check replica status for {db_instance_id}: {e}")
        return False

def promote_read_replica(db_instance_id: str) -> Dict[str, Any]:
    """Promote the RDS read replica to standalone instance."""
    try:
        # Check if instance is still a read replica
        if not is_read_replica(db_instance_id):
            logger.warning(f"DB instance {db_instance_id} is not a read replica or already promoted")
            return {'already_promoted': True}
        
        # Check current state
        current_state = check_db_instance_state(db_instance_id)
        if current_state != 'available':
            logger.error(f"DB instance {db_instance_id} is in state '{current_state}', cannot promote")
            raise ValueError(f"DB instance not in available state: {current_state}")
        
        logger.info(f"Promoting RDS read replica: {db_instance_id}")
        promote_response = rds_client.promote_read_replica(
            DBInstanceIdentifier=db_instance_id,
            BackupRetentionPeriod=7,
            PreferredBackupWindow='03:00-04:00',
            PreferredMaintenanceWindow='sun:04:00-sun:05:00'
        )
        
        logger.info(f"Promotion initiated for {db_instance_id}")
        return promote_response
        
    except rds_client.exceptions.InvalidDBInstanceStateFault as e:
        logger.warning(f"DB instance {db_instance_id} invalid state for promotion: {e}")
        raise
    except ClientError as e:
        logger.error(f"AWS error during promotion of {db_instance_id}: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error during promotion: {e}")
        raise

def wait_for_promotion(db_instance_id: str, max_wait_minutes: int = 15) -> Dict[str, Any]:
    """Wait for DB instance to become available after promotion with timeout."""
    try:
        waiter = rds_client.get_waiter('db_instance_available')
        logger.info(f"Waiting for DB instance {db_instance_id} to become available (max {max_wait_minutes} minutes)...")
        
        waiter.wait(
            DBInstanceIdentifier=db_instance_id,
            WaiterConfig={
                'Delay': 30,  # Check every 30 seconds
                'MaxAttempts': max_wait_minutes * 2  # 30-second intervals
            }
        )
        
        # Get instance details after promotion
        response = rds_client.describe_db_instances(DBInstanceIdentifier=db_instance_id)
        db_instance = response['DBInstances'][0]
        
        logger.info(f"DB instance {db_instance_id} is now available")
        return {
            'endpoint': db_instance['Endpoint']['Address'],
            'port': db_instance['Endpoint']['Port'],
            'status': db_instance['DBInstanceStatus']
        }
        
    except WaiterError as e:
        logger.error(f"Timeout waiting for DB instance {db_instance_id} to become available: {e}")
        raise
    except ClientError as e:
        logger.error(f"Error waiting for DB instance {db_instance_id}: {e}")
        raise

def update_secret_with_new_endpoint(secret_name: str, new_endpoint: str, new_port: int) -> None:
    """Update Secrets Manager secret with new database endpoint."""
    try:
        # Get current secret value
        current_secret = get_secret_value(secret_name)
        
        # Update with new endpoint information
        updated_secret = current_secret.copy()
        updated_secret['host'] = new_endpoint
        updated_secret['port'] = new_port
        
        # Add timestamp for tracking
        updated_secret['last_updated'] = int(time.time())
        updated_secret['failover_timestamp'] = int(time.time())
        
        logger.info(f"Updating secret '{secret_name}' with new endpoint: {new_endpoint}:{new_port}")
        
        secretsmanager_client.update_secret(
            SecretId=secret_name,
            SecretString=json.dumps(updated_secret)
        )
        
        logger.info(f"Secret '{secret_name}' updated successfully")
        
    except Exception as e:
        logger.error(f"Failed to update secret '{secret_name}': {e}")
        raise

def lambda_handler(event, context):
    """Main Lambda handler for DR failover."""
    start_time = time.time()
    logger.info(f"DR Lambda started. Event: {json.dumps(event, default=str)}")
    
    try:
        # Validate environment variables
        env_vars = validate_environment()
        
        # Validate execution region
        lambda_region = env_vars['AWS_REGION']
        expected_region = 'us-east-1'
        
        if lambda_region != expected_region:
            error_msg = f"Lambda executing in {lambda_region}, expected {expected_region}"
            logger.error(error_msg)
            return {
                'statusCode': 400,
                'body': json.dumps({'error': error_msg})
            }
        
        # Parse SNS message
        try:
            sns_record = event['Records'][0]['Sns']
            message = json.loads(sns_record['Message'])
            alarm_name = message['AlarmName']
            new_state = message['NewStateValue']
            alarm_reason = message.get('NewStateReason', 'Unknown')
        except (KeyError, json.JSONDecodeError, IndexError) as e:
            error_msg = f"Invalid SNS message format: {e}"
            logger.error(error_msg)
            return {
                'statusCode': 400,
                'body': json.dumps({'error': error_msg})
            }
        
        logger.info(f"Processing alarm '{alarm_name}' with state '{new_state}'. Reason: {alarm_reason}")
        
        # Check if this is the alarm we care about and it's in ALARM state
        if new_state != 'ALARM' or alarm_name != env_vars['PRIMARY_HEALTH_ALARM_NAME']:
            logger.info(f"No action needed. Alarm: {alarm_name}, State: {new_state}")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No action required', 'alarm': alarm_name, 'state': new_state})
            }
        
        # Start DR failover process
        logger.info("Starting DR failover process...")
        
        db_instance_id = env_vars['DR_DB_REPLICA_ID']
        secret_name = env_vars['DR_DB_CREDENTIALS_SECRET_NAME']
        notification_topic = env_vars['NOTIFICATION_TOPIC_ARN']
        
        # Send initial notification
        send_notification(
            notification_topic,
            "DR Failover Started",
            f"DR failover initiated for alarm: {alarm_name}\nReason: {alarm_reason}\nPromoting replica: {db_instance_id}"
        )
        
        try:
            # Promote the read replica
            promotion_result = promote_read_replica(db_instance_id)
            
            if promotion_result.get('already_promoted'):
                logger.info("DB instance already promoted, updating secret with current endpoint")
                # Get current endpoint details
                current_details = wait_for_promotion(db_instance_id, max_wait_minutes=1)
            else:
                # Wait for promotion to complete
                current_details = wait_for_promotion(db_instance_id)
            
            # Update Secrets Manager with new endpoint
            update_secret_with_new_endpoint(
                secret_name,
                current_details['endpoint'],
                current_details['port']
            )
            
            execution_time = time.time() - start_time
            success_message = f"DR failover completed successfully in {execution_time:.2f} seconds"
            logger.info(success_message)
            
            # Send success notification
            send_notification(
                notification_topic,
                "DR Failover Completed Successfully",
                f"{success_message}\n"
                f"New endpoint: {current_details['endpoint']}:{current_details['port']}\n"
                f"Promoted instance: {db_instance_id}"
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'DR failover completed successfully',
                    'endpoint': current_details['endpoint'],
                    'port': current_details['port'],
                    'execution_time_seconds': execution_time
                })
            }
            
        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"DR failover failed after {execution_time:.2f} seconds: {str(e)}"
            logger.error(error_msg, exc_info=True)
            
            # Send failure notification
            send_notification(
                notification_topic,
                "DR Failover Failed",
                f"{error_msg}\nAlarm: {alarm_name}\nReplica: {db_instance_id}"
            )
            
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': error_msg,
                    'execution_time_seconds': execution_time
                })
            }
    
    except Exception as e:
        execution_time = time.time() - start_time
        error_msg = f"Critical error in DR Lambda after {execution_time:.2f} seconds: {str(e)}"
        logger.error(error_msg, exc_info=True)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg,
                'execution_time_seconds': execution_time
            })
        }