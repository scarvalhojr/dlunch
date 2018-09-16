const Eateries = artifacts.require("Eateries")
const truffleAssert = require("truffle-assertions");

contract("Eateries", (accounts) => {

  let eateries;

  // Build up a new Eateries contract before each test
  beforeEach(async () => {
    eateries = await Eateries.new();
  });

  it("starts with no known eatery", async () => {
    let isValid;

    let numEateries = await eateries.getNumEateries.call();
    assert.equal(numEateries, 0, "unexpected number of eateries");

    isValid = await eateries.isValidEateryID.call(0);
    assert.equal(isValid, false,
      "unexpectedly found 0 to be a valid eatery ID");

    isValid = await eateries.isValidEateryID.call(1);
    assert.equal(isValid, false,
      "unexpectedly found 1 to be a valid eatery ID");
  });

  it("adds new eateries and retrieve details", async () => {
    var name1 = "Diner 0";
    var dist1 = 123;
    var name2 = "Diner 1";
    var dist2 = 321;

    let tx0 = await eateries.addEatery(name1, dist1);
    truffleAssert.eventEmitted(tx0, "NewEatery", (ev) => {
      return ev.eateryID == 1;
    });

    let tx1 = await eateries.addEatery(name2, dist2);
    truffleAssert.eventEmitted(tx1, "NewEatery", (ev) => {
      return ev.eateryID == 2;
    });

    let numEateries = await eateries.getNumEateries.call();
    assert.equal(numEateries, 2, "unexpected number of eateries");

    let isValid = await eateries.isValidEateryID.call(2);
    assert.equal(isValid, true,
      "unexpectedly found 2 to be an invalid eatery ID");

    let details1 = await eateries.getEateryDetails(1);
    assert.equal(details1[0], name1,
      "unexpected name retrieved for eatery 1");
    assert.equal(details1[1], dist1,
      "unexpected distance retrieved for eatery 1");

    let details2 = await eateries.getEateryDetails(2);
    assert.equal(details2[0], name2,
      "unexpected name retrieved for eatery 2");
    assert.equal(details2[1], dist2,
      "unexpected distance retrieved for eatery 2");
  });

});
