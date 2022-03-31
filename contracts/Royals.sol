pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "./abstract/Withdrawable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";



// interface IERC721Enumerable is ERC721A {
//     /**
//      * @dev Returns the total amount of tokens stored by the contract.
//      */
//     function totalSupply() external view returns (uint256);

//     /**
//      * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
//      * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
//      */
//     function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

//     /**
//      * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
//      * Use along with {totalSupply} to enumerate all tokens.
//      */
//     function tokenByIndex(uint256 index) external view returns (uint256);
// }

contract Royals is ERC721A, Ownable, Withdrawable {
    enum SaleState {
        Disabled,
        WhitelistSale
    }
    uint256 public totalSupplyLeft;
    uint256 public BatchSizeLeft;
    bytes32 public root;
    string public baseURI;
    string public baseExtension = ".json";
    ERC721Like Habibiz;

    mapping(address => uint256) burntHabibiCounts;
    mapping(address => uint256) mintAllowance;

    SaleState public saleState = SaleState.Disabled;

    event SaleStateChanged(uint256 previousState, uint256 nextState, uint256 timestamp);

    constructor(address _habibiz) ERC721A("Royals", "ROYLS") {
    
        Habibiz = ERC721Like(_habibiz);
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
            saleState == SaleState.WhitelistSale || _verify(_leaf(_address), proof),
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
        require(BatchSizeLeft>0, "Theres none left in this batch to mint");
        require(mintAllowance[msg.sender]> 0, "You have no mints left");
        require(amount <= mintAllowance[msg.sender], "You do not have enough mints allowed");

        mintAllowance[msg.sender] -= amount;     
        BatchSizeLeft-= amount;
        totalSupplyLeft -= amount;
        _safeMint(msg.sender, amount);
    }


    function burn(uint256[] calldata _habibiz) external {
        require(_habibiz.length == 8, "You must burn 8");
        for (uint256 i = 0; i < _habibiz.length; i++) {
            require(Habibiz.ownerOf(_habibiz[i]) == msg.sender, "At least one Habibi is not owned by you.");

            Habibiz.transferFrom(msg.sender, address(this), _habibiz[i]);
            //_burn(uint256 tokenId);
            burntHabibiCounts[msg.sender] +=1;    
        }
        if(burntHabibiCounts[msg.sender] % 8 == 0){
            mintAllowance[msg.sender] +=1;
        }

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

    function setBatchSize(uint256 size) external onlyOwner{
        require(
            totalSupplyLeft - size >= 0,
            "We have reached batch limit"
        );
        BatchSizeLeft = size;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    // function withdrawNFTs() public payable onlyOwner {
    //     (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    //     require(success);
    // }


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
  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, Strings.toString(tokenId), baseExtension))
        : "";
  }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        
        super.safeTransferFrom(from, to, tokenId, _data);
    }


    //nice to haves:
    // function walletOfOwner(address _owner) 
    //     public
    //     view
    //     returns (
    //         uint256[] memory){
        
    //     uint256 ownerTokenCount = balanceOf(_owner);
    //     uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    //     for (uint256 i; i < ownerTokenCount; i++) {
    //     tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    //     }
    //     return tokenIds;
    // }

    // function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
    //     require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
    //     return _ownedTokens[owner][index];
    // }

}

interface ERC721Like {
    function balanceOf(address holder_) external view returns (uint256);

    function ownerOf(uint256 id_) external view returns (address);

    function walletOfOwner(address _owner) external view returns (uint256[] calldata);

    function isApprovedForAll(address operator_, address address_) external view returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}



/*/
Some questions:

1- Do we want to just hardcode whitelist in contract and just have a setter function that can add to it? or merkletrees ?
2- What do you want us to do with burns? just burn it or transfer to one of your wallets ?
3- Are we doing 1 mint at a time, or should they mint multiples ?
4- Will they all be revealed right away? or will they mint unrevealed
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
*/


