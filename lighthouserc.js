module.exports = {
  ci: {
    collect: {
      numberOfRuns: 3,
      url: [process.env.TEST_URL, `${process.env.TEST_URL}/blog`],
      settings: {
        configPath: "lighthouse-config.js"
      }
    }
  }
};
