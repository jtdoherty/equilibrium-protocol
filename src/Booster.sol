// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// NOTE: This is a highly simplified booster for testing.
// A real one would use a Reward contract like OpenZeppelin's ERC20Staking.
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract Booster is Ownable {
    IERC20 public immutable M_YB_BTC;
    mapping(address => uint256) public stakedBalances;
    uint256 public totalStaked;

    constructor(address _mYbbBtcAddress) Ownable(msg.sender) {
        M_YB_BTC = IERC20(_mYbbBtcAddress);
    }

    function stake(uint256 _amount) external {
        stakedBalances[msg.sender] += _amount;
        totalStaked += _amount;
        M_YB_BTC.transferFrom(msg.sender, address(this), _amount);
    }

    // The RewardDistributor will call this to fund the Booster.
    function notifyRewardAmount(uint256 _reward, uint256 _duration) external {
        // In a real contract, this would start a rewards distribution period.
        // For now, it just needs to exist to satisfy the interface.
    }
}