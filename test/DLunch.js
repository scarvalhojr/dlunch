const Eateries = artifacts.require("Eateries")
const DLunch = artifacts.require("DLunch")
const truffleAssert = require("truffle-assertions");

contract("DLunch", (accounts) => {

  const contractName = "Contract Name";
  const minProposalTimeSec = 60;
  const minNumEaters = 2;
  let dlunch;

  // Build up a new DLunch contract before each test
  beforeEach(async () => {
    dlunch = await DLunch.new(contractName, minProposalTimeSec, minNumEaters);
  });

  it("should start with no provided parameters", async () => {
    let _name = await dlunch.name.call();
    assert.equal(contractName, _name, "unexpected contract name");

    let _minTime = await dlunch.minProposalTimeSec.call();
    assert.equal(minProposalTimeSec, _minTime,
      "unexpected minimum proposal time setting");

    let _minEaters = await dlunch.minNumEaters.call();
    assert.equal(minNumEaters, _minEaters,
      "unexpected minimum number of eaters setting");
  });

});
