// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract NodeFiCommissionManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint16 public commissionBps;
    address public treasury;
    uint256[50] private __gap;

    event CommissionParamsUpdated(uint16 newCommissionBps);
    event TreasuryUpdated(address indexed newTreasury);
    event CommissionTaken(
        address indexed token,
        address indexed payer,
        uint256 commissionAmount
    );

    function initialize(uint16 _commissionBps, address _treasury) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        require(_commissionBps <= 10000, "CommissionManager: invalid bps");
        require(_treasury != address(0), "CommissionManager: zero treasury");
        commissionBps = _commissionBps;
        treasury = _treasury;
    }

    function setCommissionBps(uint16 _commissionBps)
        external
        onlyOwner
        whenNotPaused
    {
        require(_commissionBps <= 10000, "CommissionManager: invalid bps");
        commissionBps = _commissionBps;
        emit CommissionParamsUpdated(_commissionBps);
    }

    function setTreasury(address _treasury)
        external
        onlyOwner
        whenNotPaused
    {
        require(_treasury != address(0), "CommissionManager: zero treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function handleCommission(
        IERC20Upgradeable token,
        address payer,
        uint256 grossAmount
    ) external nonReentrant whenNotPaused returns (uint256 netAmount) {
        require(payer != address(0), "CommissionManager: invalid payer");
        uint256 commissionAmount = (grossAmount * commissionBps) / 10000;
        if (commissionAmount > 0) {
            token.safeTransferFrom(payer, treasury, commissionAmount);
            emit CommissionTaken(address(token), payer, commissionAmount);
        }
        return grossAmount - commissionAmount;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
