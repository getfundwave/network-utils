import { EC2Client, DescribeInstancesCommand } from "@aws-sdk/client-ec2";

export const getPublicIpAddress = async (event) => {
  const region = event.awsEC2Region;
  const instanceId = event.instanceId;

  const client = new EC2Client({ region });

  const command = new DescribeInstancesCommand({
    InstanceIds: [instanceId],
  });

  try {
    const response = await client.send(command);
    
    const instance = response.Reservations?.[0]?.Instances?.[0];

    if (!instance) {
      throw new Error(`Instance ${instanceId} not found`);
    }

    return instance.PublicIpAddress;
  } catch (error) {
    throw error;
  }
};