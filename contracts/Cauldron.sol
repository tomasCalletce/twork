// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./utils/whiteList.sol";
import "./tokens/tWork.sol";
import "./oracles/Aggregator.sol";
import "./tokens/tcop.sol";

contract Cauldron is CollatWhiteList {

    event collatDeposited(address _depositor,uint256[] _ids,address _collatToken);
    event stableDeposited(address _depositor,uint _amount);
    event stableMint(address _minter,uint _amount);
    event liquidated(address _targetBorrower,address _collatToken,uint _val);
    event collatWithdrawn(address _withdrawer,uint256[] _ids,address _collatToken);

    // NFTs deposits
    mapping(address => mapping(uint => uint256[])) deposits;

    //User balance
    mapping(address => mapping(uint => uint)) stableBalance;

    //Oracles 
    mapping(uint => address) oracles;
    
    //Max borrow %
    uint maxBorrow = 5e17;

    //Tokens 
    Tcop tcop;

    constructor(address _tcop){
        tcop = Tcop(_tcop);
    }

    function depositCollateral(address _collatToken,uint256[] memory _ids) external {
        CollatType memory _colType = collatWhiteList[_collatToken];
        require(_colType.active,"NOT COLLAT");

        address _sender = msg.sender;
        TWork _ins = TWork(_collatToken);
        address _this = address(this);

        for(uint i = 0;i < _ids.length;i++){
            _ins.transferFrom(_sender,_this,_ids[i]);
            deposits[_sender][_colType.id].push(_ids[i]);
        }

        emit collatDeposited(_sender,deposits[_sender][_colType.id],_collatToken);
    }

    function mintStable(address _collatToken,uint _val) external{
        require(willBeSolvante(msg.sender,_collatToken,_val),"NOT SOLVENT");
        tcop.mint(msg.sender,_val);

        CollatType memory _colType = collatWhiteList[_collatToken];
        stableBalance[msg.sender][_colType.id] += _val;

        emit stableMint(msg.sender,_val);
    }

    function depositStable(address _collatToken,uint _val) external{
        CollatType memory _colType = collatWhiteList[_collatToken];
        require(_val <= stableBalance[msg.sender][_colType.id]);

        tcop.burnFrom(msg.sender,_val);
        stableBalance[msg.sender][_colType.id] -= _val;

        emit stableDeposited(msg.sender,_val);
    }

    function liquidate(address _targetBorrower,address _collatToken) external {
        require(!willBeSolvante(_targetBorrower,_collatToken,0),"USER SOLVANTE");
        CollatType memory _colType = collatWhiteList[_collatToken];
        require(_colType.active,"NOT COLLAT");

        uint _targetBalance  = stableBalance[_targetBorrower][_colType.id];
        address _liquidator = msg.sender;
        tcop.transferFrom(_liquidator,address(this),_targetBalance);

        uint256[] memory _collatIDs = deposits[_targetBorrower][_colType.id];
        TWork _ins = TWork(_collatToken);

        for(uint i = 0;i < _collatIDs.length;i++){
            _ins.transferFrom(address(this),_liquidator,_collatIDs[i]);
            delete deposits[_targetBorrower][_colType.id][i];
        }

        stableBalance[_targetBorrower][_colType.id] = 0;

        emit liquidated(_targetBorrower,_collatToken,_targetBalance);
    }

    function withdrawCollat(address _borrower,address _collatToken,uint256[] memory _ids) external {
        getCollatVal(_borrower,_collatToken,_ids.length);

        CollatType memory _colType = collatWhiteList[_collatToken];
        address _sender = msg.sender;

        TWork _ins = TWork(_collatToken);

        for(uint i = 0;i < _ids.length;i++){
            require(_ins.ownerOf(_ids[i]) == address(this));
            _ins.transferFrom(address(this),_sender,_ids[i]);
            if(idInList(_ids,_ids[i])){
                delete deposits[_borrower][_colType.id];
            }
        }
        
        emit collatWithdrawn(_borrower,_ids,_collatToken);
    }

    function willBeSolvante(address _borrower,address _collatToken,uint _newVal) internal view returns(bool) {
        CollatType memory _colType = collatWhiteList[_collatToken];

        return (stableBalance[_borrower][_colType.id]+_newVal) <= getCollatVal(_borrower,_collatToken,0)*maxBorrow;
    }

    function getCollatVal(address _borrower,address _collatToken,uint toWithdraw) internal view returns(uint){
        CollatType memory _colType = collatWhiteList[_collatToken];
        require(deposits[_borrower][_colType.id].length >= toWithdraw,"OVER LIMIT");

        Aggregator _oracle = Aggregator(oracles[_colType.id]);
        uint price = _oracle.latestRoundData().answer;

        return price*(deposits[_borrower][_colType.id].length-toWithdraw);
    }

    function idInList(uint256[] memory _ids,uint _target) internal pure returns(bool){
        for(uint i = 0;i < _ids.length;i++){
            if(_ids[i] == _target){
                return true;
            }
        }
        return false;
    }
    
}
