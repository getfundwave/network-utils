import { EC2Client, DescribeInstancesCommand } from "@aws-sdk/client-ec2";

export const getPublicIpAddress = async (
  region: string, 
  instanceId: string
): Promise<string> => {
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

    if (!instance.PublicIpAddress) {
      throw new Error(`Instance ${instanceId} does not have a public IP address`);
    }

    return instance.PublicIpAddress;
  } catch (error) {
    throw error;
  }
}; 