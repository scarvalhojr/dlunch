const Eateries = artifacts.require("Eateries")
const truffleAssert = require("truffle-assertions");

contract("Eateries", (accounts) => {

  let eateries;

  // Build up a new Eateries contract before each test
  beforeEach(async () => {
    eateries = await Eateries.new();
  });

  it("should start with no known eatery", async () => {
    let numEateries = await eateries.getNumEateries.call();
    assert.equal(numEateries, 0, "unexpected number of eateries");

    let isValid = await eateries.isValidEateryID.call(0);
    assert.equal(isValid, false,
      "unexpectedly found 0 to be a valid eatery ID");
  });

  it("should add new eateries and retrieve their details", async () => {
    var name0 = "Diner 0";
    var dist0 = 123;
    var name1 = "Diner 1";
    var dist1 = 321;

    let tx0 = await eateries.addEatery(name0, dist0);
    truffleAssert.eventEmitted(tx0, "NewEatery", (ev) => {
      return ev.eateryID == 0;
    });

    let tx1 = await eateries.addEatery(name1, dist1);
    truffleAssert.eventEmitted(tx1, "NewEatery", (ev) => {
      return ev.eateryID == 1;
    });

    let numEateries = await eateries.getNumEateries.call();
    assert.equal(numEateries, 2, "unexpected number of eateries");

    let isValid = await eateries.isValidEateryID.call(1);
    assert.equal(isValid, true,
      "unexpectedly found 1 to be an invalid eatery ID");

    let details0 = await eateries.getEateryDetails(0);
    assert.equal(details0[0], name0,
      "unexpected name retrieved for eatery 0");
    assert.equal(details0[1], dist0,
      "unexpected distance retrieved for eatery 0");

    let details1 = await eateries.getEateryDetails(1);
    assert.equal(details1[0], name1,
      "unexpected name retrieved for eatery 1");
    assert.equal(details1[1], dist1,
      "unexpected distance retrieved for eatery 1");
  });

});
