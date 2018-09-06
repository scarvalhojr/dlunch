
# Introduction

DLunch is a distributed app on Ethereum for helping people decide where to go
for lunch. The app is based on smart contracts that can be deployed on an
Ethereum network and used by a group of people based on a particular location
(e.g. a workplace).

# Smart contracts

## Eateries

The `Eateries` contract allows participants (aka eaters) to register known
places to go for food (aka eateries). Each place has an ID, a name, and a
distance (in meters) from the common location.

Anyone can register a place, and places are not in any way associated with the
person who registered them. It is up for the eaters to agree what the name
actually means and if the registered distance is accurate.

An Ethereum event is created any time a new place is registered, i.e eaters
are notified about new places.

## DLunch

This is the main contract for proposing, joining, and deciding the location of
eating events.

The contract has a `name` that facilitates identifying multiple instances of
this contract, allowing the same contract to be deployed and used by different
groups of people on the same Ethereum network. It also has two configuration
parameters that are set at deployment time: `minProposalTimeSec`, the minimum
amount of time ahead needed to propose eating events (in seconds), and
`minNumEaters`, the minimum number of eaters needed for an eating event to be
confirmed.

This contract requires a deployed `Eateries` contract to map eatery IDs to the
actual names and distances.

An eating event is initially proposed with a decision time using the
`proposeEating` function. Anyone can join the event by adding their own
suggestion using the `joinEating` function. When the decision time is up, the
decision can be reached by calling the `decideEating` function. Details about
the eating proposals and decisions can be retrieved with the `getEatingProposal`
and `getEatingDecision` functions.

An Ethereum event is generated when:
* a new event is proposed,
* a decision is made,
* an event is cancelled because not enough eaters joined it.

# To-do

* Add ability to add extra weight to an eating suggestion using tokens.
* Add ability to add restrictions to eating plans using tokens.
* Prevent the following abuses:
  * creating fake events to collect more tokens
