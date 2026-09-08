const { S3Client } = require('@aws-sdk/client-s3');

const region = process.env.AWS_REGION || 'us-east-1';

const s3 = new S3Client({ region });

module.exports = s3;
