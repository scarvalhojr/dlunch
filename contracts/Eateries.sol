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

  function getNumEateries ()
    external
    view
    returns(uint)
  {
    return eateries.length;
  }

  function addEatery (string name, uint distMeters)
    external
  {
    uint eatingID = eateries.push(Eatery(name, distMeters)) - 1;
    emit NewEatery(eatingID);
  }

  function isValidEateryID (uint eateryID)
    public
    view
    returns(bool)
  {
    return (eateryID < eateries.length);
  }

  function getEateryDetails (uint eateryID)
    external
    view
    returns(string name, uint distMeters)
  {
    require(isValidEateryID(eateryID), "Unkown eatery ID.");
    Eatery storage eatery = eateries[eateryID];
    return(eatery.name, eatery.distMeters);
  }

}
