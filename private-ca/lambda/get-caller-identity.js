import https from 'https';

export const getCallerIdentity = (auth) => {
    
    const host = 'sts.ap-south-1.amazonaws.com';
    const path = '/';
    const payload = 'Action=GetCallerIdentity&Version=2011-06-15';
    
    // Set the headers
    const headers = {
      'accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Amz-Date': auth.amzDate,
      'Authorization': auth.authorizationHeader,
      'X-Amz-Security-Token': auth.sessionToken
    };
    
    const options = {
      hostname: host,
      path: path,
      method: 'POST',
      headers: headers
    };
    
    return new Promise((resolve, reject) => {
    
        const req = https.request(options, (res) => {
          let data = '';
          
          res.on('data', (chunk) => {
            data += chunk;
          });
          
          res.on('end', () => {
            try {
              resolve(JSON.parse(data));
            } catch (err) {
              reject(new Error(err));
            }
          });
        });
        
        req.on('error', (error) => {
        //   console.error('Error:', error);
            reject(new Error(error));
        });
        
        req.write(payload);
        req.end();
    });

};