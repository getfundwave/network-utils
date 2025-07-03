import https from 'https';
import { LambdaEvent, CallerIdentityResponse } from './types/index.js';

export const getCallerIdentity = (event: LambdaEvent): Promise<CallerIdentityResponse> => {
  const auth = event.auth;
  const region = event.awsSTSRegion;
  const host = 'sts.' + region + '.amazonaws.com';
  const path = '/';
  const payload = 'Action=GetCallerIdentity&Version=2011-06-15';
    
  // Set the headers
  const headers = {
    'accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
    'X-Amz-Date': auth.amzDate,
    'Authorization': auth.authorizationHeader,
    'X-Amz-Security-Token': auth.sessionToken,
    'Aud': 'FundwaveCA'
  };

  const options: https.RequestOptions = {
    hostname: host,
    path: path,
    method: 'POST',
    headers: headers
  };
    
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk: string) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsedData = JSON.parse(data) as CallerIdentityResponse;
          resolve(parsedData);
        } catch (err) {
          reject(new Error(`Failed to parse response: ${err}`));
        }
      });
    });
    
    req.on('error', (error: Error) => {
      reject(new Error(`Request failed: ${error.message}`));
    });
    
    req.write(payload);
    req.end();
  });
}; 