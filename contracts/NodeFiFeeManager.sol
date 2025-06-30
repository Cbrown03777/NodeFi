// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract NodeFiFeeManager is 
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public underlying;
    address public treasury;
    address public burnAddress;
    uint16  public feeBps;
    uint16  public burnRateBps;
    address public vault;
    uint256[50] private __gap;

    event FeeParamsUpdated(uint16 feeBps, uint16 burnRateBps);
    event TreasuryUpdated(address indexed treasury);
    event BurnAddressUpdated(address indexed burnAddress);
    event VaultUpdated(address indexed vault);
    event FeeDistributed(
        address indexed caller,
        uint256 totalFee,
        uint256 burnAmount,
        uint256 treasuryAmount
    );

    function initialize(
        address _underlying,
        address _treasury,
        address _burnAddress,
        uint16  _feeBps,
        uint16  _burnRateBps,
        address _vault
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        require(_treasury != address(0), "FeeManager: zero treasury");
        require(_burnAddress != address(0), "FeeManager: zero burn addr");
        require(_vault != address(0),     "FeeManager: zero vault");
        require(_feeBps <= 1000,          "FeeManager: feeBps > 10%");
        require(_burnRateBps <= 10000,    "FeeManager: burnRateBps > 100%");

        underlying    = _underlying;
        treasury      = _treasury;
        burnAddress   = _burnAddress;
        feeBps        = _feeBps;
        burnRateBps   = _burnRateBps;
        vault         = _vault;
    }

    function setTreasury(address _treasury) external onlyOwner whenNotPaused {
        require(_treasury != address(0), "FeeManager: zero treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setBurnAddress(address _burnAddress) external onlyOwner whenNotPaused {
        require(_burnAddress != address(0), "FeeManager: zero burn addr");
        burnAddress = _burnAddress;
        emit BurnAddressUpdated(_burnAddress);
    }

    function setFeeBps(uint16 _feeBps) external onlyOwner whenNotPaused {
        require(_feeBps <= 1000, "FeeManager: feeBps > 10%");
        feeBps = _feeBps;
        emit FeeParamsUpdated(feeBps, burnRateBps);
    }

    function setBurnRateBps(uint16 _burnRateBps) external onlyOwner whenNotPaused {
        require(_burnRateBps <= 10000, "FeeManager: burnRateBps > 100%");
        burnRateBps = _burnRateBps;
        emit FeeParamsUpdated(feeBps, burnRateBps);
    }

    function setVault(address _vault) external onlyOwner whenNotPaused {
        require(_vault != address(0), "FeeManager: zero vault");
        vault = _vault;
        emit VaultUpdated(_vault);
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    function distributeFee(uint256 feeAmount) external payable nonReentrant whenNotPaused {
        require(msg.sender == vault, "FeeManager: only vault");
        if (underlying == address(0)) {
            require(msg.value == feeAmount, "FeeManager: ETH amt mismatch");
        } else {
            require(msg.value == 0, "FeeManager: no ETH accepted");
            IERC20Upgradeable(underlying).safeTransferFrom(msg.sender, address(this), feeAmount);
        }
        uint256 burnAmt     = (feeAmount * burnRateBps) / 10000;
        uint256 treasuryAmt = feeAmount - burnAmt;
        if (underlying == address(0)) {
            if (burnAmt > 0) {
                (bool ok,) = burnAddress.call{value: burnAmt}("");
                require(ok, "FeeManager: burn ETH failed");
            }
            (bool ok2,) = treasury.call{value: treasuryAmt}("");
            require(ok2, "FeeManager: treasury ETH failed");
        } else {
            if (burnAmt > 0) {
                IERC20Upgradeable(underlying).safeTransfer(burnAddress, burnAmt);
            }
            IERC20Upgradeable(underlying).safeTransfer(treasury, treasuryAmt);
        }
        emit FeeDistributed(msg.sender, feeAmount, burnAmt, treasuryAmt);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
