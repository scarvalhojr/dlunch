pragma solidity ^0.4.23;

contract Eaters {

  // Owner of the deployed contract; only owners can register, suspend
  // and unsuspend eaters
  address public owner;

  // The possible states of eaters
  enum EaterState { Unknown, Registered, Suspended }

  // Mapping of eater addresses to eater state
  mapping (address => EaterState) eaterState;

  // When a new eater is registered
  event EaterRegistered(address eaterAddress);

  // When an eater is suspended
  event EaterSuspended(address eaterAddress);

  // When an eater is unsuspended
  event EaterUnsuspended(address eaterAddress);

  constructor () public {
    owner = msg.sender;
  }

  modifier ownerOnly ()
  {
    require(msg.sender == owner, "Action restricted to the contract owner.");
    _;
  }

  modifier knownEater (address eaterAddress)
  {
    require(eaterState[eaterAddress] != EaterState.Unknown, "Unknown eater.");
    _;
  }

  function registerEater (address eaterAddress)
    external
    ownerOnly()
  {
    if (eaterState[eaterAddress] == EaterState.Unknown) {
      eaterState[eaterAddress] = EaterState.Registered;
      emit EaterRegistered(eaterAddress);
    }
  }

  function getEaterState (address eaterAddress)
    external
    view
    returns(EaterState)
  {
    return eaterState[eaterAddress];
  }

  function suspendEater (address eaterAddress)
    external
    ownerOnly()
    knownEater(eaterAddress)
  {
    if (eaterState[eaterAddress] != EaterState.Suspended) {
      eaterState[eaterAddress] = EaterState.Suspended;
      emit EaterSuspended(eaterAddress);
    }
  }

  function unsuspendEater (address eaterAddress)
    external
    ownerOnly()
    knownEater(eaterAddress)
  {
    if (eaterState[eaterAddress] != EaterState.Registered) {
      eaterState[eaterAddress] = EaterState.Registered;
      emit EaterUnsuspended(eaterAddress);
    }
  }

  function isRegistered (address eaterAddress)
    external
    view
    returns(bool)
  {
    return eaterState[eaterAddress] == EaterState.Registered;
  }

}
