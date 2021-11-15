const ERC1155 = artifacts.require("ShowtimeMT");

module.exports = function (deployer) {
    deployer.deploy(ERC1155, { overwrite: false });
};
