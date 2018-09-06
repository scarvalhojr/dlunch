pragma solidity ^0.4.23;

import "./Eateries.sol";

contract DLunch {

  // Name of each instance of a deployed contract
  string public name;

  // Minimum amount of time ahead needed to propose eating events (in seconds)
  uint public minProposalTimeSec;

  // Minimum number of eaters needed for an eating event to be confirmed
  uint public minNumEaters;

  // Associated Eateries contract with list of known eateries
  Eateries public eateries;

  // The three possible states of eating proposals
  enum EatingState { Proposed, Decided, Cancelled }

  // Structure of eating proposals
  struct Eating {
    uint decisionTime;
    uint decidedEateryID;
    EatingState state;
    mapping (address => uint) suggestions;
  }

  // List of eating proposals
  Eating[] eatings;

  // An event when a new eating is proposed
  event NewEating(uint);

  // An event when an eating is decided
  event EatingDecided(uint);

  // An event when an eating is cancelled because not enough eaters joined
  event EatingCancelled(uint);

  // balance of Eater tokens of all eaters
  mapping (address => uint) eaterBalances;

  constructor (
    string _name,
    uint _minProposalTimeSec,
    uint _minNumEaters,
    address eateriesAddress
  )
    public
  {
    name = _name;
    minProposalTimeSec = _minProposalTimeSec;
    minNumEaters = _minNumEaters;
    eateries = Eateries(eateriesAddress);
  }

  function getNumEatings ()
    external
    view
    returns(uint)
  {
    return eatings.length;
  }

  function proposeEating (uint decisionTime)
    external
  {
    require(decisionTime > block.timestamp + minProposalTimeSec,
      "Decision time is too soon.");

    Eating memory eating = Eating(decisionTime, 0, EatingState.Proposed);
    uint eatingID = eatings.push(eating) - 1;

    // TODO: emit event
    // emit NewEating(eatingID);
  }

  modifier isValidEatingID (uint eatingID)
  {
    require(eatingID < eatings.length, "Unknown eating plan.");
    _;
  }

  function getEatingProposal (uint eatingID)
    external
    view
    isValidEatingID(eatingID)
    returns(uint, EatingState)
  {
    Eating storage eating = eatings[eatingID];
    return(eating.decisionTime, eating.state);
  }

  function joinEating (uint eatingID, uint suggestedEateryID)
    external
    isValidEatingID(eatingID)
  {
    require(eateries.isValidEateryID(suggestedEateryID), "Unknown eatery ID.");
    Eating storage eating = eatings[eatingID];
    require(eating.state == EatingState.Proposed,
      "Unable to join eating as it is already decided or cancelled.");
    eating.suggestions[msg.sender] = suggestedEateryID;
  }

  function getEatingDecision (uint eatingID)
    external
    view
    isValidEatingID(eatingID)
    returns(uint, uint)
  {
    Eating storage eating = eatings[eatingID];
    require(eating.state == EatingState.Decided,
      "Eating plan not yet decided or cancelled.");
    return(eating.decisionTime, eating.decidedEateryID);
  }

  function decideEating (uint eatingID)
    public
    isValidEatingID(eatingID)
  {
    Eating storage eating = eatings[eatingID];
    require(eating.state == EatingState.Proposed,
      "Eating plan already decided or cancelled.");
    require(block.timestamp > eating.decisionTime,
      "Decision time not reached.");

    // TODO: decide where to go
    eating.decidedEateryID = 1;
    eating.state = EatingState.Decided;

    // TODO: emit event
    // emit EatingDecided(eatingID);
    // emit EatingCancelled(eatingID);
  }

}
