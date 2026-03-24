module.exports = {
  apps: [{
    name: 'infomatrix',
    script: './server.js',
    env: {
      PORT: process.env.PORT || 7000,
      NODE_ENV: process.env.NODE_ENV || 'production',
      ADMIN_TOKEN: process.env.ADMIN_TOKEN || 'infomatrix2026',
      DATABASE_URL: process.env.DATABASE_URL || 'postgresql://infomatrix:infomatrix2026@localhost:5432/infomatrix'
    }
  }]
};
