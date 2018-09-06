var Eateries = artifacts.require("./Eateries.sol")
var DLunch = artifacts.require("./Dlunch.sol")

module.exports = function (deployer) {
  deployer.deploy(Eateries).then(function() {
    return deployer.deploy(DLunch, "", 60, 2, Eateries.address);
  }).then(function() { })
}
