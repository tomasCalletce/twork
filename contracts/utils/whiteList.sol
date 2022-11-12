//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

struct CollatType{
    bytes32 unique;
    bool active;
    uint8 id;
}

contract CollatWhiteList is Ownable {
    mapping(address => CollatType) public collatWhiteList;

    function addToList (address _newCollat,uint8 _id,bytes32  _unique) external onlyOwner{
        collatWhiteList[_newCollat] = CollatType(_unique,true,_id);
    }

    function deleteFromList (address _toDelete) external onlyOwner{
        collatWhiteList[_toDelete].active = false;
    }
}