// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import {ILpBTC, IERC20} from "./interfaces/ILpBTC.sol";
import {ILpBTCVault} from "./interfaces/ILpBTCVault.sol";
import {IMetaAggregationRouterV2} from "./interfaces/IMetaAggregationRouterV2.sol";

/**
 * @title   PrelaunchPoints
 * @author  Loop
 * @notice  Staking points contract for the prelaunch of Loop Protocol.
 */
contract PrelaunchPoints {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ILpBTC;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ILpBTC public lpBTC;
    ILpBTCVault public lpBTCVault;
    IERC20 public immutable WBTC;
    address public immutable exchangeProxy;

    address public owner;
    address public proposedOwner;

    uint256 public totalSupply;
    uint256 public totalLpBTC;
    mapping(address => uint256) public maxDepositCap;
    mapping(address => bool) public isTokenAllowed;

    enum Exchange {
        Swap,
        SwapSimpleMode
    }

    bytes4 public constant SWAP_SELECTOR = 0xe21fd0e9;
    bytes4 public constant SWAP_SIMPLE_MODE_SELECTOR = 0x8af033fb;

    uint32 public loopActivation;
    uint32 public startClaimDate;
    uint32 public constant TIMELOCK = 7 days;
    bool public emergencyMode;

    mapping(address => mapping(address => uint256)) public balances; // User -> Token -> Balance

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Locked(address indexed user, uint256 amount, address indexed token, bytes32 indexed referral);
    event StakedVault(address indexed user, uint256 amount, uint256 typeIndex);
    event Converted(uint256 amounWBTC, uint256 amountlpBTC);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Claimed(address indexed user, address indexed token, uint256 reward);
    event Recovered(address token, uint256 amount);
    event OwnerProposed(address newOwner);
    event OwnerUpdated(address newOwner);
    event LoopAddressesUpdated(address loopAddress, address vaultAddress);
    event SwappedTokens(address sellToken, uint256 sellAmount, uint256 buyWBTCAmount);
    event NewTokenAllowed(address token);
    event DepositMaxCapUpdated(address indexed token, uint256 amount);
    event EmergencyModeSet(bool mode);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidToken();
    error NothingToClaim();
    error TokenNotAllowed(address token);
    error CannotLockZero();
    error CannotClaimZero();
    error CannotWithdrawZero();
    error UseClaimInstead();
    error FailedToSendEther();
    error SellTokenApprovalFailed();
    error SwapCallFailed();
    error WrongSelector(bytes4 selector);
    error WrongDataTokens(address inputToken, address outputToken);
    error WrongDataAmount(uint256 inputTokenAmount);
    error WrongRecipient(address recipient);
    error WrongExchange();
    error LoopNotActivated();
    error NotValidToken();
    error NotAuthorized();
    error NotProposedOwner();
    error CurrentlyNotPossible();
    error NoLongerPossible();
    error ReceiveDisabled();
    error ArrayLenghtsDoNotMatch();
    error MaxDepositCapReached(address token);

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /**
     * @param _exchangeProxy address of the Kyberswap protocol exchange proxy
     * @param _wbtcAddress   address of WBTC
     * @param _allowedTokens list of token addresses to allow for locking
     * @param _initialMaxCap list of intial max deposit caps
     * @dev _initialMaxCap[0] corresponds to WBTC, and the rest corresponds to
     *      _allowedTokens in same order
     */
    constructor(
        address _exchangeProxy,
        address _wbtcAddress,
        address[] memory _allowedTokens,
        uint256[] memory _initialMaxCap
    ) {
        owner = msg.sender;
        exchangeProxy = _exchangeProxy;
        WBTC = IERC20(_wbtcAddress);

        loopActivation = uint32(block.timestamp + 120 days);
        startClaimDate = 4294967295; // Max uint32 ~ year 2107

        // Allow intital list of tokens
        uint256 length = _allowedTokens.length;
        if (_initialMaxCap.length != length + 1) {
            revert ArrayLenghtsDoNotMatch();
        }

        for (uint256 i = 0; i < length;) {
            isTokenAllowed[_allowedTokens[i]] = true;
            _setDepositMaxCap(_allowedTokens[i], _initialMaxCap[i + 1]);
            unchecked {
                i++;
            }
        }
        isTokenAllowed[_wbtcAddress] = true;
        _setDepositMaxCap(_wbtcAddress, _initialMaxCap[0]);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks a valid token
     * @param _token     address of token to lock
     * @param _amount    amount of token to lock
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lock(address _token, uint256 _amount, bytes32 _referral) external {
        _processLock(_token, _amount, msg.sender, _referral);
    }

    /**
     * @notice Locks a valid token for a given address
     * @param _token     address of token to lock
     * @param _amount    amount of token to lock
     * @param _for       address for which token is locked
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockFor(address _token, uint256 _amount, address _for, bytes32 _referral) external {
        _processLock(_token, _amount, _for, _referral);
    }

    /**
     * @dev Generic internal locking function that updates rewards based on
     *      previous balances, then update balances.
     * @param _token       Address of the token to lock
     * @param _amount      Units of token to add to the users balance
     * @param _receiver    Address of user who will receive the stake
     * @param _referral    Address of the referral user
     */
    function _processLock(address _token, uint256 _amount, address _receiver, bytes32 _referral)
        internal
        onlyBeforeDate(startClaimDate)
    {
        if (_amount == 0) {
            revert CannotLockZero();
        }
        if (!isTokenAllowed[_token]) {
            revert TokenNotAllowed(_token);
        }
        if (IERC20(_token).balanceOf(address(this)) + _amount > maxDepositCap[_token]) {
            revert MaxDepositCapReached(_token);
        }
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        if (_token == address(WBTC)) {
            totalSupply += _amount;
        }
        balances[_receiver][_token] += _amount;

        emit Locked(_receiver, _amount, _token, _referral);
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM AND WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a user to get their vested lpBTC
     * @param _token      Address of the token to convert to lpBTC
     * @param _percentage Proportion in % of tokens to withdraw. NOT useful fo WBTC
     * @param _exchange   Exchange identifier where the swap takes place
     * @param _data       Swap data obtained from Kyberswap API
     */
    function claim(address _token, uint8 _percentage, Exchange _exchange, bytes calldata _data)
        external
        onlyAfterDate(startClaimDate)
    {
        _claim(_token, msg.sender, _percentage, _exchange, _data);
    }

    /**
     * @dev Called by a user to get their vested lpBTC and stake them in a
     *      Loop vault for extra rewards
     * @param _token      Address of the token to convert to lpBTC
     * @param _percentage Proportion in % of tokens to withdraw. NOT useful for WBTC
     * @param _exchange   Exchange identifier where the swap takes place
     * @param _typeIndex  lock type index determining lock period and rewards multiplier.
     * @param _data       Swap data obtained from Kyberswap API
     */
    function claimAndStake(
        address _token,
        uint8 _percentage,
        Exchange _exchange,
        uint256 _typeIndex,
        bytes calldata _data
    ) external onlyAfterDate(startClaimDate) {
        uint256 claimedAmount = _claim(_token, address(this), _percentage, _exchange, _data);
        lpBTC.approve(address(lpBTCVault), claimedAmount);
        lpBTCVault.stake(claimedAmount, msg.sender, _typeIndex);

        emit StakedVault(msg.sender, claimedAmount, _typeIndex);
    }

    /**
     * @dev Claim logic. If necessary converts token to WBTC before depositing into lpBTC contract.
     */
    function _claim(address _token, address _receiver, uint8 _percentage, Exchange _exchange, bytes calldata _data)
        internal
        returns (uint256 claimedAmount)
    {
        if (_percentage == 0) {
            revert CannotClaimZero();
        }
        uint256 userStake = balances[msg.sender][_token];
        if (userStake == 0) {
            revert NothingToClaim();
        }
        if (_token == address(WBTC)) {
            claimedAmount = userStake.mulDiv(totalLpBTC, totalSupply);
            balances[msg.sender][_token] = 0;
            if (_receiver != address(this)) {
                lpBTC.safeTransfer(_receiver, claimedAmount);
            }
        } else {
            uint256 userClaim = userStake * _percentage / 100;
            _validateData(_token, userClaim, _exchange, _data);
            balances[msg.sender][_token] = userStake - userClaim;
            uint256 balanceWbtcBefore = WBTC.balanceOf(address(this));

            // Swap token to WBTC
            _fillQuote(IERC20(_token), userClaim, _data);

            // Convert swapped WBTC to lpBTC (1 to 1 conversion)
            claimedAmount = WBTC.balanceOf(address(this)) - balanceWbtcBefore;
            WBTC.approve(address(lpBTC), claimedAmount);
            lpBTC.deposit(claimedAmount, _receiver);
        }
        emit Claimed(msg.sender, _token, claimedAmount);
    }

    /**
     * @dev Called by a staker to withdraw all their WBTC or LRT
     * Note Can only be called before claiming lpBTC has started.
     * In emergency mode can be called at any time.
     * @param _token      Address of the token to withdraw
     */
    function withdraw(address _token) external {
        if (!emergencyMode) {
            if (block.timestamp >= startClaimDate) {
                revert NoLongerPossible();
            }
        }

        uint256 lockedAmount = balances[msg.sender][_token];
        balances[msg.sender][_token] = 0;

        if (lockedAmount == 0) {
            revert CannotWithdrawZero();
        }
        if (_token == address(WBTC)) {
            if (block.timestamp >= startClaimDate) {
                revert UseClaimInstead();
            }
            totalSupply -= lockedAmount;
        }
        IERC20(_token).safeTransfer(msg.sender, lockedAmount);

        emit Withdrawn(msg.sender, _token, lockedAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Called by a owner to convert all the locked WBTC to get lpBTC
     */
    function convertAllBTC() external onlyAuthorized onlyBeforeDate(startClaimDate) {
        if (block.timestamp <= TIMELOCK + loopActivation) {
            revert LoopNotActivated();
        }

        // deposits all the WBTC to lpBTC contract. Receives lpBTC back
        WBTC.approve(address(lpBTC), totalSupply);
        lpBTC.deposit(totalSupply, address(this));

        // If there is extra lpBTC (sent by external actor) then it is distributed amoung all WBTC users
        totalLpBTC = lpBTC.balanceOf(address(this));

        // Claims of lpBTC can start immediately after conversion.
        startClaimDate = uint32(block.timestamp);

        emit Converted(totalSupply, totalLpBTC);
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

    /**
     * @notice Sets the lpBTC contract address
     * @param _loopAddress address of the lpBTC contract
     * @dev Can only be set once before 120 days have passed from deployment.
     *      After that users can only withdraw WBTC.
     */
    function setLoopAddresses(address _loopAddress, address _vaultAddress)
        external
        onlyAuthorized
        onlyBeforeDate(loopActivation)
    {
        lpBTC = ILpBTC(_loopAddress);
        lpBTCVault = ILpBTCVault(_vaultAddress);
        loopActivation = uint32(block.timestamp);

        emit LoopAddressesUpdated(_loopAddress, _vaultAddress);
    }

    /**
     * @param _token address of a wrapped LRT token
     * @dev ONLY add wrapped LRT tokens. Contract not compatible with rebase tokens.
     */
    function allowToken(address _token) external onlyAuthorized {
        isTokenAllowed[_token] = true;
        emit NewTokenAllowed(_token);
    }

    /**
     * @param _tokens addresses of the tokens to change the max cap
     * @param _amounts corresponding amounts of the tokens to change the max cap
     * @dev tokens must be allowed to change the max deposit cap
     */
    function setDepositMaxCaps(address[] memory _tokens, uint256[] memory _amounts) external onlyAuthorized {
        uint256 length = _tokens.length;
        if (length != _amounts.length) {
            revert ArrayLenghtsDoNotMatch();
        }

        for (uint256 i = 0; i < length;) {
            _setDepositMaxCap(_tokens[i], _amounts[i]);
            emit DepositMaxCapUpdated(_tokens[i], _amounts[i]);
            unchecked {
                i++;
            }
        }
    }

    /**
     * @param _mode boolean to activate/deactivate the emergency mode
     * @dev On emergency mode all withdrawals are accepted at
     */
    function setEmergencyMode(bool _mode) external onlyAuthorized {
        emergencyMode = _mode;
        emit EmergencyModeSet(_mode);
    }

    /**
     * @dev Allows the owner to recover other ERC20s mistakingly sent to this contract
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAuthorized {
        if (tokenAddress == address(lpBTC) || isTokenAllowed[tokenAddress]) {
            revert NotValidToken();
        }
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);

        emit Recovered(tokenAddress, tokenAmount);
    }

    /**
     * Disable receive ETH
     */
    receive() external payable {
        revert ReceiveDisabled();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Validates the data sent from Kyberswap API to match desired behaviour
     * @param _token     address of the token to sell
     * @param _amount    amount of token to sell
     * @param _exchange  exchange identifier where the swap takes place
     * @param _data      swap data from Kyberswap API
     */
    function _validateData(address _token, uint256 _amount, Exchange _exchange, bytes calldata _data) internal view {
        address inputToken;
        address outputToken;
        uint256 inputTokenAmount;
        address recipient;
        bytes4 selector;

        if (_exchange == Exchange.Swap) {
            (inputToken, outputToken, inputTokenAmount, recipient, selector) = _decodeSwapTargetData(_data);
            if (selector != SWAP_SELECTOR) {
                revert WrongSelector(selector);
            }
        } else if (_exchange == Exchange.SwapSimpleMode) {
            (inputToken, outputToken, inputTokenAmount, recipient, selector) = _decodeSwapSimpleMode(_data);
            if (selector != SWAP_SIMPLE_MODE_SELECTOR) {
                revert WrongSelector(selector);
            }
        } else {
            revert WrongExchange();
        }

        if (inputToken != _token) {
            revert WrongDataTokens(inputToken, outputToken);
        }

        if (outputToken != address(WBTC)) {
            revert WrongDataTokens(inputToken, outputToken);
        }

        if (inputTokenAmount != _amount) {
            revert WrongDataAmount(inputTokenAmount);
        }
        if (recipient != address(this)) {
            revert WrongRecipient(recipient);
        }
    }

    /**
     * @notice Decodes the data sent from Kyber API when exchanges are used via swap function
     * @param _data      swap data from Kyber API
     */
    function _decodeSwapTargetData(bytes calldata _data)
        internal
        pure
        returns (address inputToken, address outputToken, uint256 inputTokenAmount, address recipient, bytes4 selector)
    {
        assembly {
            let p := _data.offset
            selector := calldataload(p)
        }
        (,,, IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,) =
            abi.decode(_data[36:], (address, address, bytes, IMetaAggregationRouterV2.SwapDescriptionV2, bytes));
        inputToken = address(desc.srcToken);
        outputToken = address(desc.dstToken);
        recipient = desc.dstReceiver;
        inputTokenAmount = desc.amount;
    }

    /**
     * @notice Decodes the data sent from Kyber API when exchanges are used via swapSimpleMode function
     * @param _data      swap data from Kyber API
     */
    function _decodeSwapSimpleMode(bytes calldata _data)
        internal
        pure
        returns (address inputToken, address outputToken, uint256 inputTokenAmount, address recipient, bytes4 selector)
    {
        assembly {
            let p := _data.offset
            selector := calldataload(p)
        }
        (, IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,,) =
            abi.decode(_data[4:], (address, IMetaAggregationRouterV2.SwapDescriptionV2, bytes, bytes));
        inputToken = address(desc.srcToken);
        outputToken = address(desc.dstToken);
        recipient = desc.dstReceiver;
        inputTokenAmount = desc.amount;
    }

    /**
     *
     * @param _sellToken     The `sellTokenAddress` field from the API response.
     * @param _amount       The `sellAmount` field from the API response.
     * @param _swapCallData  The `data` field from the API response.
     */
    function _fillQuote(IERC20 _sellToken, uint256 _amount, bytes calldata _swapCallData) internal {
        // Track our balance of the buyToken to determine how much we've bought.
        uint256 boughtWbtcAmount = WBTC.balanceOf(address(this));

        if (!_sellToken.approve(exchangeProxy, _amount)) {
            revert SellTokenApprovalFailed();
        }

        (bool success,) = payable(exchangeProxy).call{value: 0}(_swapCallData);

        if (!success) {
            revert SwapCallFailed();
        }

        // Use our current buyToken balance to determine how much we've bought.
        boughtWbtcAmount = WBTC.balanceOf(address(this)) - boughtWbtcAmount;
        emit SwappedTokens(address(_sellToken), _amount, boughtWbtcAmount);
    }

    /**
     * @param _token   address of an authorized token
     * @param _amount  amount to set the max deposit cap for that token
     */
    function _setDepositMaxCap(address _token, uint256 _amount) internal {
        if (!isTokenAllowed[_token]) {
            revert TokenNotAllowed(_token);
        }
        maxDepositCap[_token] = _amount;
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

    modifier onlyAfterDate(uint256 limitDate) {
        if (block.timestamp <= limitDate) {
            revert CurrentlyNotPossible();
        }
        _;
    }

    modifier onlyBeforeDate(uint256 limitDate) {
        if (block.timestamp >= limitDate) {
            revert NoLongerPossible();
        }
        _;
    }
}
