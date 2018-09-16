pragma solidity ^0.4.23;

contract Eateries {

  struct Eatery {
    string  name;
    uint    distMeters;
  }

  // List of registered eateries
  Eatery[] eateries;

  // Event when a new eatery is registered
  event NewEatery(uint eateryID);

  constructor () public
  {
    // 0 is not a valid eatery ID
    eateries.push(Eatery("Nowhere", 0));
  }

  function getNumEateries ()
    external
    view
    returns(uint)
  {
    return eateries.length - 1;
  }

  function addEatery (string name, uint distMeters)
    external
  {
    uint eatingID = eateries.push(Eatery(name, distMeters)) - 1;
    emit NewEatery(eatingID);
  }

  modifier validEateryID (uint eateryID) {
    require(isValidEateryID(eateryID), "Unkown eatery ID.");
    _;
  }

  function isValidEateryID (uint eateryID)
    public
    view
    returns(bool)
  {
    return (eateryID > 0 && eateryID < eateries.length);
  }

  function getEateryDetails (uint eateryID)
    external
    view
    validEateryID(eateryID)
    returns(string name, uint distMeters)
  {
    Eatery storage eatery = eateries[eateryID];
    return(eatery.name, eatery.distMeters);
  }

  function getEateryDistance (uint eateryID)
    external
    view
    validEateryID(eateryID)
    returns(uint distMeters)
  {
    Eatery storage eatery = eateries[eateryID];
    return(eatery.distMeters);
  }

}
