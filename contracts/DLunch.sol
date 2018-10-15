pragma solidity ^0.4.23;

import "./Eaters.sol";
import "./Eateries.sol";

contract DLunch {

  // Name associated with the deployed contract
  string public name;

  // Time zone for mapping timestamps to days
  int public utcOffsetHours;

  // Minimum amount of time ahead needed to propose eating events (in seconds)
  uint public minDecisionTimeSec;

  // Maximum amount of time eatings can allow eaters to join or vote after
  // decision time (30min); eatings cannot be cancelled before closing time
  uint public constant maxClosingTimeSec = 30 * 60;

  // Maximum number of eating events allowed in the same day
  uint public constant maxEatingsPerDay = 2;

  // Minimum number of eaters needed for an eating event to be confirmed
  uint public constant minNumEaters = 3;

  // How many Eater tokens it costs to vote for an eatery beyond free votes
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
    uint winningEateryDist;
    uint numEaters;
    mapping (address => uint) eaterFreeVoteCount;
    mapping (bytes32 => bool) eaterToEateryFreeVote;
    mapping (uint => address) eateryProposer;
    mapping (uint => uint) eateryVoteCount;
  }

  // Eating proposals indexed by decision time
  mapping (uint => Eating) eatings;

  // Number of eating events proposed in a day
  mapping (uint => uint) numEatings;

  // Last day an eatery won an eating event
  mapping (uint => uint) lastEatingDay;

  // When a new eating is proposed
  event NewEating(uint decisionTime, uint closingTime);

  // When an eater joins an eating plan
  event EaterJoined(uint decisionTime, address eater, uint suggestedEateryID);

  // When an eatery gets a vote
  event EateryVoted(uint decisionTime, address eater, uint eateryID);

  // When an eating is decided
  event EatingDecided(uint decisionTime, uint eateryID, address winningEater);

  // When an eating is cancelled (because not enough eaters joined
  // or because no eatery received more than 1 vote)
  event EatingCancelled(uint decisionTime);

  constructor (
    string _name,
    int _utcOffsetHours,
    uint _minDecisionTimeSec
  )
    public
  {
    require(_utcOffsetHours >= -12 && _utcOffsetHours <= 14,
      "Invaild UTC offset.");
    name = _name;
    utcOffsetHours = _utcOffsetHours;
    minDecisionTimeSec = _minDecisionTimeSec;
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
    require(eateries.isValidEateryID(eateryID), "Invalid eatery ID.");
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

  modifier joinedEating (uint decisionTime)
  {
    require(eatings[decisionTime].eaterFreeVoteCount[msg.sender] > 0,
      "You have not joined this eating yet.");
    _;
  }

  function checkMyBalance ()
    external
    view
    returns(uint)
  {
    return eaterBalance[msg.sender];
  }

  function timestampToDay(uint timestamp)
    internal
    view
    returns(uint)
  {
    return uint(int(timestamp) + utcOffsetHours * 3600) / 86400;
  }

  function proposeEating (
    uint decisionTime,
    uint closingTime
  )
    external
    registeredEater(msg.sender)
  {
    require(eatings[decisionTime].state == EatingState.Unknown,
      "Eating already proposed for this time.");
    require(closingTime >= decisionTime,
      "Closing time should be greater than or equals to decision time.");
    require(decisionTime >= block.timestamp + minDecisionTimeSec,
      "Decision time is too soon.");
    require(closingTime - decisionTime <= maxClosingTimeSec,
      "Closing time is too far away.");

    uint day = timestampToDay(decisionTime);

    require(numEatings[day] + 1 <= maxEatingsPerDay,
      "Maximum number of eatings reached for this day.");

    numEatings[day] += 1;
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
    return(eating.closingTime, eating.winningEateryID, eating.winningEateryDist,
      eating.numEaters);
  }

  function freeVoteIndex(uint eateryID)
    internal
    view
    returns(bytes32)
  {
    return keccak256(abi.encodePacked(msg.sender, eateryID));
  }

  function joinEating (uint decisionTime, uint suggestedEateryID)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    validEateryID(suggestedEateryID)
  {
    Eating storage eating = eatings[decisionTime];
    require(eating.eaterFreeVoteCount[msg.sender] == 0,
      "You already joined this eating.");

    eating.numEaters += 1;
    eating.eaterFreeVoteCount[msg.sender] = 1;
    eating.eaterToEateryFreeVote[freeVoteIndex(suggestedEateryID)] = true;
    recordEateryVote(eating, suggestedEateryID);

    emit EaterJoined(decisionTime, msg.sender, suggestedEateryID);
  }

  function recordEateryVote (Eating storage eating, uint votedEateryID)
    internal
  {
    if (eating.eateryVoteCount[votedEateryID] == 0) {
      // Eatery hasn't been suggested yet, keep track of who suggested it
      eating.eateryProposer[votedEateryID] = msg.sender;
    }

    // Update vote count
    eating.eateryVoteCount[votedEateryID] += 1;

    uint votes = eating.eateryVoteCount[votedEateryID];
    uint winningVotes = eating.eateryVoteCount[eating.winningEateryID];

    if (votes >= winningVotes) {
      uint votedDist = eateries.getEateryDistance(votedEateryID);
      if (votes > winningVotes || votedDist < eating.winningEateryDist) {
        // The voted eatery now has more votes, or
        // has same number of votes but it's closer
        eating.winningEateryID = votedEateryID;
        eating.winningEateryDist = votedDist;
      }
    }
  }

  function freeVote (uint decisionTime, uint suggestedEateryID)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    validEateryID(suggestedEateryID)
    joinedEating(decisionTime)
  {
    Eating storage eating = eatings[decisionTime];

    require(eating.eaterFreeVoteCount[msg.sender] + 1 < eating.numEaters,
      "No free votes currently available to you for this eating.");

    bytes32 idx = freeVoteIndex(suggestedEateryID);
    require(eating.eaterToEateryFreeVote[idx] == false,
      "You cannot vote multiple times on the same eatery for free.");

    eating.eaterFreeVoteCount[msg.sender] += 1;
    eating.eaterToEateryFreeVote[idx] = true;
    recordEateryVote(eating, suggestedEateryID);

    emit EateryVoted(decisionTime, msg.sender, suggestedEateryID);
  }

  function paidVote (uint decisionTime, uint suggestedEateryID)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    validEateryID(suggestedEateryID)
    joinedEating(decisionTime)
  {
    require(eaterBalance[msg.sender] >= paidVoteCost,
      "Insufficient balance of Eater tokens for paid vote.");

    eaterBalance[msg.sender] -= paidVoteCost;
    recordEateryVote(eatings[decisionTime], suggestedEateryID);

    emit EateryVoted(decisionTime, msg.sender, suggestedEateryID);
  }

  function getMyFreeVoteCounts (uint decisionTime)
    external
    view
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    beforeClosingTime(decisionTime)
    joinedEating(decisionTime)
    returns(uint, uint)
  {
    Eating storage eating = eatings[decisionTime];
    uint freeVotes = eating.numEaters <= 2 ? 1 : eating.numEaters - 1;
    return(freeVotes, freeVotes - eating.eaterFreeVoteCount[msg.sender]);
  }

  function decideEating (uint decisionTime)
    external
    registeredEater(msg.sender)
    eatingOpen(decisionTime)
    joinedEating(decisionTime)
  {
    Eating storage eating = eatings[decisionTime];
    require(block.timestamp >= decisionTime, "Decision time not reached.");

    bool canBeDecided = (eating.numEaters >= minNumEaters) &&
      (eating.eateryVoteCount[eating.winningEateryID] > 1);

    if (block.timestamp > eating.closingTime && !canBeDecided) {
      eating.state = EatingState.Cancelled;
      emit EatingCancelled(decisionTime);
    } else {
      require(eating.numEaters >= minNumEaters,
        "Not enough eaters joined.");
      require(eating.eateryVoteCount[eating.winningEateryID] > 1,
        "No eatery has received more than 1 vote yet.");

      // Add Eater token to winning eater
      address winner = eating.eateryProposer[eating.winningEateryID];
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

    return(eating.winningEateryID,
      eating.eateryProposer[eating.winningEateryID]);
  }
}
