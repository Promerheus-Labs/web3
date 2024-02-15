// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Leaderboard is Ownable {
  constructor() Ownable(msg.sender) {}

  uint leaderboardLength = 100;
  mapping (uint => User) public leaderboard;
    
  struct User {
    string user;
    uint score;
  }
    
  function addScore(string memory user, uint score) public onlyOwner returns (bool) {
    if (leaderboard[leaderboardLength-1].score >= score) return false;

    for (uint i=0; i<leaderboardLength; i++) {
      // find where to insert the new score
      if (leaderboard[i].score < score) {

        // shift leaderboard
        User memory currentUser = leaderboard[i];
        for (uint j=i+1; j<leaderboardLength+1; j++) {
          User memory nextUser = leaderboard[j];
          leaderboard[j] = currentUser;
          currentUser = nextUser;
        }

        // insert
        leaderboard[i] = User({
          user: user,
          score: score
        });

        delete leaderboard[leaderboardLength];

        return true;
      }
    }
    return false;
  }
}
