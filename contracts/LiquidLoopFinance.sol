// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title LiquidLoop Finance
 * @notice A leverage-loop lending + auto-compounding protocol.
 * @dev This is a template. Requires price feeds, audits, robust liquidation logic.
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256); // 1e8 decimals
}

contract LiquidLoopFinance {
    // -------------------------------------------------------
    // STRUCTS
    // -------------------------------------------------------
    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 loopCount;
        bool exists;
    }

    // -------------------------------------------------------
    // STATE
    // -------------------------------------------------------
    IERC20 public immutable collateralToken; // e.g., WETH
    IERC20 public immutable stableToken;     // e.g., USDC/DAI

    IPriceOracle public oracle;

    uint256 public constant MAX_LOAN_TO_VALUE = 70_000;  // 70% LTV (scaled 1e5)
    uint256 public constant LIQUIDATION_THRESHOLD = 80_000; // 80%
    uint256 public constant PRECISION = 1e5;

    mapping(address => Position) public positions;

    address public owner;

    // -------------------------------------------------------
    // EVENTS
    // -------------------------------------------------------
    event LoopOpened(address indexed user, uint256 collateral, uint256 loops);
    event LoopExpanded(address indexed user, uint256 newCollateral, uint256 loopsAdded);
    event LoopUnwound(address indexed user, uint256 returnedCollateral);
    event Liquidated(address indexed user, uint256 burnedCollateral, uint256 repaidDebt);
    event OracleUpdated(address newOracle);

    // -------------------------------------------------------
    // MODIFIERS
    // -------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier positionExists() {
        require(positions[msg.sender].exists, "No position");
        _;
    }

    // -------------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------------
    constructor(address _collateral, address _stable, address _oracle) {
        collateralToken = IERC20(_collateral);
        stableToken = IERC20(_stable);
        oracle = IPriceOracle(_oracle);
        owner = msg.sender;
    }

    // -------------------------------------------------------
    // INTERNAL HELPERS
    // -------------------------------------------------------
    function _getCollateralValue(uint256 amount) internal view returns (uint256) {
        // Collateral token price in stableToken units
        uint256 price = oracle.getPrice(address(collateralToken));
        return (amount * price) / 1e8;
    }

    function _maxBorrow(uint256 collateralAmount) internal view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(collateralAmount);
        return (collateralValue * MAX_LOAN_TO_VALUE) / PRECISION;
    }

    function _healthFactor(address user) public view returns (uint256) {
        Position memory p = positions[user];
        if (p.debt == 0) return type(uint256).max;

        uint256 collateralValue = _getCollateralValue(p.collateral);
        return (collateralValue * PRECISION) / p.debt;
    }

    // -------------------------------------------------------
    // CORE: CREATE LEVERAGE LOOP
    // -------------------------------------------------------
    function openLoop(uint256 collateralAmount, uint256 loops) external {
        require(!positions[msg.sender].exists, "Already exists");
        require(loops > 0 && loops <= 10, "Loops too high");

        // Transfer user collateral
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);

        uint256 currentCollateral = collateralAmount;
        uint256 totalDebt = 0;

        // Main leverage loop
        for (uint256 i = 0; i < loops; i++) {
            uint256 borrowable = _maxBorrow(currentCollateral) - totalDebt;
            if (borrowable == 0) break;

            // Borrow stablecoins (mint in template)
            stableToken.transfer(msg.sender, 0); // placeholder for real lending pool
            totalDebt += borrowable;

            // Buy more collateral with borrowed stablecoins
            // *DEX logic not included; assume swap executed offchain*
            uint256 extraCollateral = borrowable / 2; // placeholder conversion rate

            currentCollateral += extraCollateral;
        }

        positions[msg.sender] = Position({
            collateral: currentCollateral,
            debt: totalDebt,
            loopCount: loops,
            exists: true
        });

        emit LoopOpened(msg.sender, currentCollateral, loops);
    }

    // -------------------------------------------------------
    // EXPAND LOOP
    // -------------------------------------------------------
    function boostLoop(uint256 extraCollateral, uint256 moreLoops) external positionExists {
        require(moreLoops > 0 && moreLoops <= 10, "Bad loops");

        collateralToken.transferFrom(msg.sender, address(this), extraCollateral);

        Position storage p = positions[msg.sender];
        p.collateral += extraCollateral;

        uint256 totalDebt = p.debt;

        // additional looping
        for (uint256 i = 0; i < moreLoops; i++) {
            uint256 borrowable = _maxBorrow(p.collateral) - totalDebt;
            if (borrowable == 0) break;

            totalDebt += borrowable;

            uint256 extraCol = borrowable / 2; // placeholder
            p.collateral += extraCol;
        }

        p.debt = totalDebt;
        p.loopCount += moreLoops;

        emit LoopExpanded(msg.sender, p.collateral, moreLoops);
    }

    // -------------------------------------------------------
    // EXIT LOOP
    // -------------------------------------------------------
    function unwindLoop() external positionExists {
        Position memory p = positions[msg.sender];

        // Repay debt (assume repaid separately)
        // Return collateral to user
        collateralToken.transfer(msg.sender, p.collateral);

        delete positions[msg.sender];

        emit LoopUnwound(msg.sender, p.collateral);
    }

    // -------------------------------------------------------
    // LIQUIDATION
    // -------------------------------------------------------
    function liquidate(address user) external {
        require(_healthFactor(user) < LIQUIDATION_THRESHOLD, "Healthy");

        Position memory p = positions[user];
        require(p.exists, "No position");

        uint256 seizeCollateral = (p.collateral * 90_000) / PRECISION; // 90% collateral
        uint256 repayDebt = p.debt;

        // Liquidator receives bonus collateral
        collateralToken.transfer(msg.sender, seizeCollateral);

        // Treasury takes the rest
        uint256 leftover = p.collateral - seizeCollateral;
        collateralToken.transfer(owner, leftover);

        delete positions[user];

        emit Liquidated(user, seizeCollateral, repayDebt);
    }

    // -------------------------------------------------------
    // ADMIN
    // -------------------------------------------------------
    function updateOracle(address newOracle) external onlyOwner {
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(newOracle);
    }
}
