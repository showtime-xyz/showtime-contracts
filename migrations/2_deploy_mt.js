const ShowtimeMT = artifacts.require("ShowtimeMT");

module.exports = function (deployer) {
    // this used to work, now I'm getting the following error:
    // Error: while migrating ShowtimeMT: Invalid number of parameters for "undefined". Got 1 expected 0!

    // deployer.deploy(ShowtimeMT, { overwrite: false });

    deployer.deploy(ShowtimeMT);
};
