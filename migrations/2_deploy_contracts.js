var Eateries = artifacts.require("./Eateries.sol")
var DLunch = artifacts.require("./Dlunch.sol")

module.exports = function (deployer) {
  deployer.deploy(DLunch, "DLunch Group", 0, 600);
}
