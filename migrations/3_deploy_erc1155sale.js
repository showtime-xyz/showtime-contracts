const MT = artifacts.require("ShowtimeMT");
const ERC1155Sale = artifacts.require("ERC1155Sale");

module.exports = async function (deployer) {
    const mt = await MT.new();
    console.log("nft address:", mt.address);
    const sale = await ERC1155Sale.new(mt.address, []);
    console.log("sale address:", sale.address);
};
