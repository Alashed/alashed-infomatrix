module.exports = {
  apps: [{
    name: 'infomatrix',
    script: './server.js',
    env_production: {
      PORT: 7000,
      NODE_ENV: 'production',
      ADMIN_TOKEN: 'infomatrix2026',
      DATABASE_URL: 'postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix'
    },
    env: {
      PORT: process.env.PORT || 7000,
      NODE_ENV: process.env.NODE_ENV || 'production',
      ADMIN_TOKEN: process.env.ADMIN_TOKEN || 'infomatrix2026',
      DATABASE_URL: process.env.DATABASE_URL || 'postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix'
    }
  }]
};
