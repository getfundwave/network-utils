import {SSMClient, GetParametersCommand } from "@aws-sdk/client-ssm";

export async function getParameter (keys, ssmPrefix = "", ssmSuffix = "") {
  let input = [];
  for(let key of keys){
    input.push(ssmPrefix + key + ssmSuffix);
  }
  const client = new SSMClient({
    region: process.env.AWS_REGION
  });
  let command = new GetParametersCommand({
    Names: input,
    WithDecryption: true
  });
  const result = await client.send(command);
  return result.Parameters.reduce((acc,val)=>{
    acc[val.Name] = val.Value;
    return acc;
  },{})
};

// module.exports = { getParameter };
