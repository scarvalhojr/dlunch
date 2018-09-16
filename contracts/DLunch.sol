pragma solidity ^0.4.23;

import "./Eaters.sol";
import "./Eateries.sol";

contract DLunch {

  // Name associated with the deployed contract
  string public name;

  // Minimum amount of time ahead needed to propose eating events (in seconds)
  uint public minProposalTimeSec;

  // Maximum amount of time eatings can allow eaters to join or vote after
  // decision time (30min); eatings cannot be cancelled before closing time
  uint public constant maxClosingTimeSec = 30 * 60;

  // TODO: enforce maxEatingsPerDay
  // Maximum number of eating events allowed in the same day
  uint public constant maxEatingsPerDay = 2;

  // Minimum number of eaters needed for an eating event to be confirmed
  uint public constant minNumEaters = 3;

  // How many tokens it costs to vote for an eatery beyond free votes
  uint public constant paidVoteCost = 2;

  // Associated Eateries contract with list of known eateries
  Eateries public eateries;

  // Associated Eaters contract with list of registered eaters
  Eaters public eaters;

  // Mapping of eater addresses to token balances
  mapping (address => uint) eaterBalance;

  // The possible states of eating proposals
  enum EatingState { Unknown, Open, Decided, Cancelled }

  // Structure of eating proposals
  struct Eating {
    uint closingTime;
    EatingState state;
    uint winningEateryID;
    uint winningDistance;
    uint numEaters;
    mapping (address => uint) numFreeVotes;
    // TODO: prevent eaters voting on the same eatery for free
    // mapping (address + uint => bool) suggested;
    mapping (uint => address) proposer;
    mapping (uint => uint) votes;
  }

  // Eating proposals indexed by decision time
  mapping (uint => Eating) eatings;

  // When a new eating is proposed
  event NewEating(uint decisionTime, uint closingTime);

  // When an eater joins an eating plan
  event EaterJoined(uint decisionTime, address eater, uint suggestedEateryID);

  // When an eatery gets another vote
  event EateryVoted(uint decisionTime, address eater, uint eateryID);

  // When an eating is decided
  event EatingDecided(uint decisionTime, uint eateryID, address winningEater);

  // When an eating is cancelled because not enough eaters joined
  // or because no eatery received more than 1 vote
  event EatingCancelled(uint decisionTime);

  constructor (
    string _name,
    uint _minProposalTimeSec
  )
    public
  {
    name = _name;
    minProposalTimeSec = _minProposalTimeSec;
    eateries = new Eateries();
    eaters = new Eaters(msg.sender);
  }

  modifier registeredEater (address eaterAddress)
  {
    require(eaters.isRegistered(eaterAddress),
      "Eater suspended or not registered.");
    _;
  }

  modifier validEateryID (uint eateryID)
  {
    require(eateries.isValidEateryID(eateryID), "Unknown eatery.");
    _;
  }

  modifier eatingOpen (uint decisionTime)
  {
    require(eatings[decisionTime].state == EatingState.Open,
      "Eating not open.");
    _;
  }

  modifier beforeClosingTime (uint decisionTime)
  {
    require(block.timestamp < eatings[decisionTime].closingTime,
      "Eating reached closing time.");
    _;
  }

  function checkMyBalance ()
    external
    view
    returns(uint)
  {
    return eaterBalance[msg.sender];
  }

  function proposeEating (
    uint decisionTime,
    uint closingTime
  )
    external
    registeredEater(msg.sender)
  {
    require(eatings[decisionTime].closingTime == 0,
      "Eating already proposed for this time.");
    require(closingTime >= decisionTime,
      "Closing time should be the same or later than decision time.");
    require(decisionTime >= block.timestamp + minProposalTimeSec,
      "Decision time is too soon.");
    require(closingTime - decisionTime <= maxClosingTimeSec,
      "Closing time is too late.");

    eatings[decisionTime] = Eating(closingTime, EatingState.Open, 0, 0, 0);
    emit NewEating(decisionTime, closingTime);
  }

  function getOpenEatingProposal (uint decisionTime)
    external
    view
    eatingOpen(decisionTime)
    returns(uint, uint, uint, uint)
  {
    Eating storage eating = eatings[decisionTime];
    return(eating.closingTime, eating.winningEateryID, eating.winningDistance,
      eating.numEaters);
  }

  function joinEating (uint decisionTime, uint suggestedEateryID)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    validEateryID(suggestedEateryID)
  {
    Eating storage eating = eatings[decisionTime];
    require(eating.numFreeVotes[msg.sender] == 0,
      "You already joined this eating.");

    eating.numEaters += 1;
    eating.numFreeVotes[msg.sender] = 1;
    if (eating.votes[suggestedEateryID] == 0) {
      // Eatery hasn't been suggested yet
      eating.proposer[suggestedEateryID] = msg.sender;
    }
    eating.votes[suggestedEateryID] += 1;

    // Update winning eatery if suggested has more votes
    // or same number of votes but closer
    updateWinningEatery(eating, suggestedEateryID);

    emit EaterJoined(decisionTime, msg.sender, suggestedEateryID);
  }

  function updateWinningEatery (Eating storage eating, uint suggestedEateryID)
    internal
  {
    uint winningVotes = eating.votes[eating.winningEateryID];

    if (eating.votes[suggestedEateryID] > winningVotes) {
      eating.winningEateryID = suggestedEateryID;
      eating.winningDistance = eateries.getEateryDistance(suggestedEateryID);
    } else if (eating.votes[suggestedEateryID] == winningVotes) {
      uint suggestedDistance = eateries.getEateryDistance(suggestedEateryID);
      if (suggestedDistance < eating.winningDistance) {
        eating.winningEateryID = suggestedEateryID;
        eating.winningDistance = suggestedDistance;
      }
    }
  }

  function freeVote (uint decisionTime, uint suggestedEateryID)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    validEateryID(suggestedEateryID)
  {
    Eating storage eating = eatings[decisionTime];
    require(eating.numFreeVotes[msg.sender] > 0,
      "You have not joined this eating yet.");

    require(eating.numFreeVotes[msg.sender] + 1 < eating.numEaters,
      "No free votes currently available to you for this eating.");

    // TODO: prevent voting for an eatery this eater already voted for

    eating.numFreeVotes[msg.sender] += 1;
    if (eating.votes[suggestedEateryID] == 0) {
      // Eatery hasn't been suggested yet
      eating.proposer[suggestedEateryID] = msg.sender;
    }
    eating.votes[suggestedEateryID] += 1;

    // Update winning eatery if upvoted has more votes
    // or same number of votes but closer
    updateWinningEatery(eating, suggestedEateryID);

    emit EateryVoted(decisionTime, msg.sender, suggestedEateryID);
  }

  function paidVote (uint decisionTime, uint suggestedEateryID)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    validEateryID(suggestedEateryID)
  {
    // Require balance to upvote
    require(eaterBalance[msg.sender] >= paidVoteCost,
      "Insufficient balance of EaterTokens for extra vote.");

    // reduce balance
    eaterBalance[msg.sender] -= paidVoteCost;

    Eating storage eating = eatings[decisionTime];
    if (eating.votes[suggestedEateryID] == 0) {
      // Eatery hasn't been suggested yet
      eating.proposer[suggestedEateryID] = msg.sender;
    }
    eating.votes[suggestedEateryID] += 1;

    // Update winning eatery if upvoted has more votes
    // or same number of votes but closer
    updateWinningEatery(eating, suggestedEateryID);

    emit EateryVoted(decisionTime, msg.sender, suggestedEateryID);
  }

  function getMyFreeVoteCounts (uint decisionTime)
    external
    view
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    returns(uint, uint)
  {
    Eating storage eating = eatings[decisionTime];
    uint freeVotes = eating.numEaters <= 2 ? 1 : eating.numEaters - 1;

    return(freeVotes, freeVotes - eating.numFreeVotes[msg.sender]);
  }

  function decideEating (uint decisionTime)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
  {
    Eating storage eating = eatings[decisionTime];
    require(block.timestamp >= decisionTime, "Decision time not reached.");

    bool canBeDecided = (eating.numEaters >= minNumEaters) &&
      (eating.votes[eating.winningEateryID] > 1);

    if (block.timestamp > eating.closingTime && !canBeDecided) {
      eating.state = EatingState.Cancelled;
      emit EatingCancelled(decisionTime);
    } else {
      require(eating.numEaters >= minNumEaters,
        "Not enough eaters joined.");
      require(eating.votes[eating.winningEateryID] > 1,
        "No eatery has received more than 1 vote yet.");

      // Add token to winning eater
      address winner = eating.proposer[eating.winningEateryID];
      eaterBalance[winner] += 1;
      eating.state = EatingState.Decided;
      emit EatingDecided(decisionTime, eating.winningEateryID, winner);
    }
  }

  function getEatingDecision (uint decisionTime)
    external
    view
    returns(uint, address)
  {
    Eating storage eating = eatings[decisionTime];
    require(eating.state == EatingState.Decided, "Eating not decided.");

    return(eating.winningEateryID, eating.proposer[eating.winningEateryID]);
  }
}
