pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "./abstract/Withdrawable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Beatsu is ERC721A, Ownable, Withdrawable {
    enum SaleState {
        Disabled,
        WhitelistSale
    }
    uint256 public totalSupplyLeft;
    bytes32 public root;
    string public revealUri;

    SaleState public saleState = SaleState.Disabled;

    event SaleStateChanged(uint256 previousState, uint256 nextState, uint256 timestamp);

    constructor(uint64 subscriptionId) ERC721A("Beatsu", "BEAT") VRFConsumerBaseV2(vrfCoordinator) {
    
        
        //Defaults
        totalSupplyLeft = 300; //the initial supply   
    }

    modifier whenSaleIsActive() {
        require(saleState != SaleState.Disabled, "Sale is not active");
        _;
    }

        // Check if the whitelist is enabled and the address is part of the whitelist
    modifier isWhitelisted(
        address _address,
        uint256 amount,
        bytes32[] calldata proof
    ) {
        require(
            saleState == SaleState.PublicSale || _verify(_leaf(_address), proof),
            "This address is not whitelisted or has reached maximum mints"
        );
        _;
    }

    //++++++++
    // Public functions
    //++++++++

    // Payable mint function for unrevealed NFTs
    function mint(uint256 amount, bytes32[] calldata proof) external payable whenSaleIsActive isWhitelisted(msg.sender, amount, proof) {
        require(amount <= totalSupplyLeft, "Minting would exceed cap");

        //whitelist
        if (saleState == SaleState.WhitelistSale) {
            //this should require user to have at least 8 habibiz to burn
            require( <= , "You don't have enough Habibiz to burn");
            walletWhitelistMintedCount[msg.sender] += amount;
        }
        totalSupplyLeft -= amount;
        _safeMint(msg.sender, amount);
    }

    
    //++++++++
    // Owner functions
    //++++++++
    function setRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    // Sale functions
    function setSaleState(uint256 _state) external onlyOwner {
        uint256 prevState = uint256(saleState);
        saleState = SaleState(_state);
        emit SaleStateChanged(prevState, _state, block.timestamp);
    }


    //++++++++
    // Internal functions
    //++++++++
    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }



    
    //++++++++
    // Override functions
    //++++++++
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        require(tokenId < (totalSupplyLeft + totalSupply()), "This token is greater than maxSupply");

        if (revealedTokens[tokenId] == true || revealAll == true) {
            return string(abi.encodePacked(revealUri, Strings.toString((tokenId + random) % (totalSupplyLeft + totalSupply())), ".json"));
        } else {
            return unRevealUri;
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(transfersEnabled, "Transfers are currently disabled");
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(transfersEnabled, "Transfers are currently disabled");
        super.safeTransferFrom(from, to, tokenId, _data);
    }


}





/*/
Some questions:

1- Do we want to just hardcode whitelist in contract and just have a setter function that can add to it? or merkletrees ?
/*/




/*
Project requirements:

- Batches (decided by team)
- 300 max NFT supply
- Whitelist 
- 8 Habibiz for 1 royal NFT mint



//Think this is done in the OIL contract side ://

-Staking is time locked (30,60,90) 
    -30 days: 15%
    -60 days: 30%
    -90 days: 100%

- staking 1 royal = 12000 OIL per day
- staking 2 royals = 13500 OIL PER ROYAL per day
- staking 3 royals = 15000 OIL PER ROYAL Per Day
/*