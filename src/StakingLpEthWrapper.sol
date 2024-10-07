// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILpETHStaking} from "./interfaces/ILpETHStaking.sol";
import {ILpETHVault} from "./interfaces/ILpETHVault.sol";
import {ILpETH} from "./interfaces/ILpETH.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingLpEthWrapper is ILpETHVault {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    ILpETH public immutable lpETH;
    ILpETHStaking public lpETHStaking;

    address public owner;
    address public proposedOwner;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OwnerProposed(address newOwner);
    event OwnerUpdated(address newOwner);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error StakingContractAlreadySet(address stakingContract);
    error StakingContractNotSet();
    error NotAuthorized();
    error NotProposedOwner();

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    constructor(address _lpETH) {
        owner = msg.sender;
        lpETH = ILpETH(_lpETH);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Stake tokens to receive rewards.
     * @dev Locked tokens cannot be withdrawn for defaultLockDuration and are eligible to receive rewards.
     * @param amount to stake.
     * @param onBehalfOf address for staking.
     */
    function stake(uint256 amount, address onBehalfOf, uint256 /*typeIndex*/ ) external {
        if (address(lpETHStaking) == address(0)) {
            revert StakingContractNotSet();
        }
        SafeERC20.safeTransferFrom(lpETH, msg.sender, address(this), amount);
        lpETH.approve(address(lpETHStaking), amount);
        lpETHStaking.deposit(amount, onBehalfOf);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyAuthorized() {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Sets a staking contract
     * @param _stakingContract address of the new staking contract
     */
    function setStakingContract(address _stakingContract) external onlyAuthorized {
        if (address(lpETHStaking) != address(0)) {
            revert StakingContractAlreadySet(address(lpETHStaking));
        }
        lpETHStaking = ILpETHStaking(_stakingContract);
    }

    /**
     * @notice Sets a new proposedOwner
     * @param _owner address of the new owner
     */
    function proposeOwner(address _owner) external onlyAuthorized {
        proposedOwner = _owner;

        emit OwnerProposed(_owner);
    }

    /**
     * @notice Proposed owner accepts the ownership.
     * Can only be called by current proposed owner.
     */
    function acceptOwnership() external {
        if (msg.sender != proposedOwner) {
            revert NotProposedOwner();
        }
        owner = proposedOwner;
        emit OwnerUpdated(owner);
    }
}
