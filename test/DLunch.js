const Eaters = artifacts.require("Eaters")
const Eateries = artifacts.require("Eateries")
const DLunch = artifacts.require("DLunch")
const truffleAssert = require("truffle-assertions");

contract("DLunch", (accounts) => {

  // TODO: mock block timestamp to avoid timing issues

  const contractName = "Contract Name";
  const minProposalTimeSec = 1;
  const normalProposalTimeSec = 5;
  const eatery1 = 1;
  const eatery2 = 2;
  const eatery3 = 3;
  const eatery4 = 4;
  const unknownEatery = 5;
  let dlunch, eaters, eateries;

  // Build a new DLunch contract, register eaters and eateries before each test
  beforeEach(async () => {
    dlunch = await DLunch.new(contractName, minProposalTimeSec);
    let eatersAddress = await dlunch.eaters.call();
    eaters = Eaters.at(eatersAddress);
    let eateriesAddress = await dlunch.eateries.call();
    eateries = Eateries.at(eateriesAddress);

    await eaters.registerEater(accounts[0]);
    await eaters.registerEater(accounts[1]);
    await eaters.registerEater(accounts[2]);
    await eaters.registerEater(accounts[3]);
    await eaters.registerEater(accounts[4]);
    await eaters.suspendEater(accounts[4]);

    await eateries.addEatery("Eatery 1", 1000);
    await eateries.addEatery("Eatery 2", 500);
    await eateries.addEatery("Eatery 3", 200);
    await eateries.addEatery("Eatery 4", 200);
  });

  it("is initialized with provided parameters", async () => {
    let _name = await dlunch.name.call();
    assert.equal(contractName, _name, "unexpected contract name");

    let _minTime = await dlunch.minProposalTimeSec.call();
    assert.equal(minProposalTimeSec, _minTime,
      "unexpected minimum proposal time setting");
  });

  it("should have 4 eaters registered and one suspended", async () => {
    let registered, state;

    registered = await eaters.isRegistered.call(accounts[0]);
    assert.equal(registered, true, "account 0 should be registered");

    registered = await eaters.isRegistered.call(accounts[1]);
    assert.equal(registered, true, "account 1 should be registered");

    registered = await eaters.isRegistered.call(accounts[2]);
    assert.equal(registered, true, "account 2 should be registered");

    registered = await eaters.isRegistered.call(accounts[3]);
    assert.equal(registered, true, "account 3 should be registered");

    // This account is suspended
    registered = await eaters.isRegistered.call(accounts[4]);
    assert.equal(registered, false, "account 4 should not be registered");

    // This account is not registered
    registered = await eaters.isRegistered.call(accounts[5]);
    assert.equal(registered, false, "account 5 should not be registered");
  });

  it("should have 4 known eateries", async () => {
    let valid;

    valid = await eateries.isValidEateryID.call(eatery1);
    assert.equal(valid, true, "eatery ID 1 should be valid");

    valid = await eateries.isValidEateryID.call(eatery2);
    assert.equal(valid, true, "eatery ID 2 should be valid");

    valid = await eateries.isValidEateryID.call(eatery3);
    assert.equal(valid, true, "eatery ID 3 should be valid");

    valid = await eateries.isValidEateryID.call(eatery4);
    assert.equal(valid, true, "eatery ID 4 should be valid");

    valid = await eateries.isValidEateryID.call(unknownEatery);
    assert.equal(valid, false, "eatery ID 5 should not be known");
  });

  it("rejects eating if decision time is too soon", async () => {
    let now = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let decisionTime = now + minProposalTimeSec - 1;
    let closingTime = decisionTime;
    let tooSoon = false;

    try {
      await dlunch.proposeEating(decisionTime, closingTime);
    } catch (error) {
      assert.include(error.message, "Decision time is too soon.");
      tooSoon = true;
    }
    assert.equal(tooSoon, true, "eating proposal should have been rejected");
  });

  it("rejects eating if proposer is suspended or not registered", async () => {
    let now = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let decisionTime = now + normalProposalTimeSec;
    let closingTime = decisionTime;
    let rejected;

    try {
      rejected = false;
      // This account is suspended
      await dlunch.proposeEating(decisionTime, closingTime,
        {from: accounts[4]});
    } catch (error) {
      assert.include(error.message, "Eater suspended or not registered.");
      rejected = true;
    }
    assert.equal(rejected, true, "eating proposal should have been rejected");

    try {
      rejected = false;
      // This account isn't registered
      await dlunch.proposeEating(decisionTime, closingTime,
        {from: accounts[5]});
    } catch (error) {
      assert.include(error.message, "Eater suspended or not registered.");
      rejected = true;
    }
    assert.equal(rejected, true, "eating proposal should have been rejected");
  });

  it("allows eating with enough decision time", async () => {
    let now = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let decisionTime = now + normalProposalTimeSec;
    let closingTime = decisionTime + 30;
    let tooSoon = false;

    let tx = await dlunch.proposeEating(decisionTime, closingTime);
    truffleAssert.eventEmitted(tx, "NewEating", (ev) => {
      return (ev.decisionTime == decisionTime) &&
        (ev.closingTime == closingTime);
    });

    let resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[0], closingTime, "unexpected closing time");
    assert.equal(resp[1], 0, "unexpected winning eatery ID");
    assert.equal(resp[2], 0, "unexpected winning distance");
    assert.equal(resp[3], 0, "unexpected number of joined eaters");
  });

  it("rejects unregistered eaters to join eating", async () => {
    let now = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let decisionTime = now + normalProposalTimeSec;
    let closingTime = decisionTime + 30;
    let rejected;

    await dlunch.proposeEating(decisionTime, closingTime);

    try {
      rejected = false;
      // This account is suspended
      await dlunch.joinEating(decisionTime, 1, {from: accounts[4]});
    } catch (error) {
      assert.include(error.message, "Eater suspended or not registered.");
      rejected = true;
    }
    assert.equal(rejected, true, "eater should have been rejected");

    try {
      rejected = false;
      // This account isn't registered
      await dlunch.joinEating(decisionTime, 1, {from: accounts[5]});
    } catch (error) {
      assert.include(error.message, "Eater suspended or not registered.");
      rejected = true;
    }
    assert.equal(rejected, true, "eater should have been rejected");
  });

  it("decides eating and gives token to winner", async () => {
    let now = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let decisionTime = now + minProposalTimeSec;
    let closingTime = decisionTime + 30;
    let balance, resp;

    await dlunch.proposeEating(decisionTime, closingTime);

    await dlunch.joinEating(decisionTime, eatery1, {from: accounts[0]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery1, "unexpected winning eatery");

    await dlunch.joinEating(decisionTime, eatery2, {from: accounts[1]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery2, "unexpected winning eatery");

    await dlunch.joinEating(decisionTime, eatery3, {from: accounts[2]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery3, "unexpected winning eatery");

    await dlunch.freeVote(decisionTime, eatery2, {from: accounts[0]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery2, "unexpected winning eatery");

    await dlunch.freeVote(decisionTime, eatery3, {from: accounts[1]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery3, "unexpected winning eatery");

    await dlunch.freeVote(decisionTime, eatery3, {from: accounts[2]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery3, "unexpected winning eatery");

    await dlunch.joinEating(decisionTime, eatery4, {from: accounts[3]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery3, "unexpected winning eatery");

    await dlunch.freeVote(decisionTime, eatery4, {from: accounts[0]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery3, "unexpected winning eatery");

    await dlunch.freeVote(decisionTime, eatery4, {from: accounts[1]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery3, "unexpected winning eatery");

    await dlunch.freeVote(decisionTime, eatery4, {from: accounts[2]});
    resp = await dlunch.getOpenEatingProposal.call(decisionTime);
    assert.equal(resp[1], eatery4, "unexpected winning eatery");

    let tx = await dlunch.decideEating(decisionTime);
    truffleAssert.eventEmitted(tx, "EatingDecided", (ev) => {
      return (ev.decisionTime == decisionTime) && (ev.eateryID == eatery4) &&
             (ev.winningEater == accounts[3]);
    });
  
    balance = await dlunch.checkMyBalance.call({from: accounts[0]});
    assert.equal(balance, 0, "unexpected balance of account 0");

    balance = await dlunch.checkMyBalance.call({from: accounts[1]});
    assert.equal(balance, 0, "unexpected balance of account 1");

    balance = await dlunch.checkMyBalance.call({from: accounts[2]});
    assert.equal(balance, 0, "unexpected balance of account 2");

    balance = await dlunch.checkMyBalance.call({from: accounts[3]});
    assert.equal(balance, 1, "unexpected balance of account 3");
  });

});
