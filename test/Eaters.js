const Eaters = artifacts.require("Eaters")
const truffleAssert = require("truffle-assertions");

contract("Eaters", (accounts) => {

  const contractOwner = accounts[0];
  const UnknownEaterState = 0;
  const RegisteredEaterState = 1;
  const SuspendedEaterState = 2;
  let esters;

  // Build up a new Eaters contract before each test
  beforeEach(async () => {
    eaters = await Eaters.new({from: contractOwner});
  });

  it("should let owner register, suspend, and unsuspend eaters", async () => {
    let state;

    let tx1 = await eaters.registerEater(accounts[1], {from: contractOwner});
    truffleAssert.eventEmitted(tx1, "EaterRegistered", (ev) => {
      return ev.eaterAddress == accounts[1];
    });

    state = await eaters.getEaterState(accounts[1]);
    assert.equal(state, RegisteredEaterState, "unexpected eater state");

    let tx2 = await eaters.suspendEater(accounts[1], {from: contractOwner});
    truffleAssert.eventEmitted(tx2, "EaterSuspended", (ev) => {
      return ev.eaterAddress == accounts[1];
    });

    state = await eaters.getEaterState(accounts[1]);
    assert.equal(state, SuspendedEaterState, "unexpected eater state");

    let tx3 = await eaters.registerEater(accounts[1], {from: contractOwner});
    truffleAssert.eventNotEmitted(tx3, "EaterUnsuspended", (ev) => {
      return ev.eaterAddress == accounts[1];
    });

    state = await eaters.getEaterState(accounts[1]);
    assert.equal(state, SuspendedEaterState, "unexpected eater state");

    let tx4 = await eaters.unsuspendEater(accounts[1], {from: contractOwner});
    truffleAssert.eventEmitted(tx4, "EaterUnsuspended", (ev) => {
      return ev.eaterAddress == accounts[1];
    });

    state = await eaters.getEaterState(accounts[1]);
    assert.equal(state, RegisteredEaterState, "unexpected eater state");
  });

});
