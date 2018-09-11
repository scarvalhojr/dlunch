pragma solidity ^0.4.23;

import "./Eaters.sol";
import "./Eateries.sol";

contract DLunch {

  // Name associated with a deployed contract
  string public name;

  // Minimum amount of time ahead needed to propose eating events (in seconds)
  uint public minProposalTimeSec;

  // Minimum number of eaters needed for an eating event to be confirmed
  uint public minNumEaters;

  // Associated Eateries contract with list of known eateries
  Eateries public eateries;

  // Associated Eaters contract with list of registered eaters
  Eaters public eaters;

  // Mapping of eater addresses to token balances
  mapping (address => uint) eaterBalance;

  // The possible states of eating proposals
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

  // When a new eating is proposed
  event NewEating(uint eatingID);

  // When an eating is decided
  event EatingDecided(uint eatingID);

  // When an eating is cancelled because not enough eaters joined
  event EatingCancelled(uint eatingID);

  constructor (
    string _name,
    uint _minProposalTimeSec,
    uint _minNumEaters
  )
    public
  {
    name = _name;
    minProposalTimeSec = _minProposalTimeSec;
    minNumEaters = _minNumEaters;
    eateries = new Eateries();
    eaters = new Eaters();
  }

  modifier registeredEater (address eaterAddress)
  {
    require(eaters.isRegistered(eaterAddress),
      "Eater suspended or not registered.");
    _;
  }

  modifier validEateryID (uint eatingID)
  {
    require(eateries.isValidEateryID(eatingID), "Unknown eatery.");
    _;
  }

  modifier validEatingID (uint eatingID)
  {
    require(eatingID < eatings.length, "Unknown eating.");
    _;
  }

  function getEaterBalance (address eaterAddress)
    external
    view
    registeredEater(eaterAddress)
    returns(uint)
  {
    return eaterBalance[eaterAddress];
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

  function getEatingProposal (uint eatingID)
    external
    view
    validEatingID(eatingID)
    returns(uint, EatingState)
  {
    Eating storage eating = eatings[eatingID];
    return(eating.decisionTime, eating.state);
  }

  function joinEating (uint eatingID, uint suggestedEateryID)
    external
    validEatingID(eatingID)
    validEateryID(suggestedEateryID)
  {
    Eating storage eating = eatings[eatingID];
    require(eating.state == EatingState.Proposed,
      "Unable to join eating as it is already decided or cancelled.");
    eating.suggestions[msg.sender] = suggestedEateryID;
  }

  function getEatingDecision (uint eatingID)
    external
    view
    validEatingID(eatingID)
    returns(uint, uint)
  {
    Eating storage eating = eatings[eatingID];
    require(eating.state == EatingState.Decided,
      "Eating plan not yet decided or cancelled.");
    return(eating.decisionTime, eating.decidedEateryID);
  }

  function decideEating (uint eatingID)
    external
    validEatingID(eatingID)
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
