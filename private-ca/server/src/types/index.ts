export interface LambdaEvent {
  body: string;
  certPubkey: string;
  action: 'generateHostSSHCert' | 'generateClientSSHCert';
  awsEC2Region?: string;
  awsSTSRegion: string;
  auth: AuthCredentials;
}

export interface AuthCredentials {
  amzDate: string;
  authorizationHeader: string;
  sessionToken: string;
}

export interface CallerIdentityResponse {
  GetCallerIdentityResponse: {
    GetCallerIdentityResult: {
      Account: string;
      Arn: string;
      UserId: string;
    };
  };
}

export interface SecretData {
  host_ca: string;
  'host_ca.pub': string;
  user_ca: string;
  'user_ca.pub': string;
}

export interface LambdaResponse {
  statusCode: number;
  body: string;
}