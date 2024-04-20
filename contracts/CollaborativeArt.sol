// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/structs/EnumerableSet.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/cryptography/ECDSA.sol";

contract CollaborativeArt is ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Structs
    struct Artist {
        address artistAddress;
        uint256 ownershipPercentage;
        bool hasSigned;
        uint256 performanceRating;
    }

    struct Milestone {
        string description;
        uint256 deadline;
        bool completed;
        uint256 budget;
    }

    struct Phase {
        string phaseName;
        mapping(uint256 => Milestone) milestones;
        uint256 totalBudget;
        string exhibition;
        uint256 milestoneCount; // Menyimpan jumlah milestone dalam fase
    }


    struct Dispute {
        string description;
        EnumerableSet.AddressSet voters;
        mapping(address => bool) voted;
        uint256 affirmativeVotes;
        uint256 totalVotes;
        bool resolved;
        bool decision;
        address arbitrator;
        uint256 resolutionDeadline;
        uint256 arbitrationFee;
    }

    struct ArtworkSale {
        bool forSale;
        uint256 price;
    }

    struct License {
        bool canReproduce;
        bool canModify;
        mapping(address => uint256) royaltyPercentage;
    }

    // State variables
    EnumerableSet.AddressSet private artists;
    mapping(address => Artist) public artistDetails;
    Counters.Counter private _tokenIds;
    Counters.Counter private _disputeIds;
    mapping(uint256 => Dispute) private disputes;
    mapping(uint256 => ArtworkSale) public artworkSales;
    mapping(uint256 => License) public artworkLicense;
    mapping(uint256 => Phase) public phases;

    address public ownerr;
    mapping(address => uint256) private artistToOwnershipPercentage;
    mapping(address => bool) private artistSigned;
    uint256 public totalOwnershipPercentage = 0;
    uint256 public artworkPrice;
    IERC20 public paymentToken;

    // Events
    event ArtistAdded(address indexed artist, uint256 ownershipPercentage);
    event DisputeCreated(uint256 indexed disputeId, string description);
    event DisputeVoted(uint256 indexed disputeId, address indexed voter, bool vote);
    event DisputeResolved(uint256 indexed disputeId, bool decision);
    event PhaseAdded(string phaseName);
    event MilestoneCompleted(uint256 phaseIndex, uint256 milestoneIndex, string description);
    event ArtworkSold(uint256 indexed tokenId, uint256 price, string message);
    event DisputeResolved(string message);
    event ArtistSigned(address indexed artist);
    event ArtworkMinted(address indexed owner, uint256 indexed tokenId, string tokenURI);
    event ArtworkExhibited(uint256 indexed tokenId, string exhibition);
    event LicenseSet(uint256 indexed tokenId, address indexed licensee, bool canReproduce, bool canModify);
    event RoyaltySet(uint256 indexed tokenId, address indexed licensee, uint256 royaltyPercentage);
    event PriceChanged(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event MilestoneAdded(uint256 indexed phaseIndex, uint256 indexed milestoneId, string description);

    // Modifiers
    modifier onlyCollaborativeArtOwner() {
        require(msg.sender == ownerr, "Only the owner can call this function");
        _;
    }

    modifier onlyArtist() {
        require(artistSigned[msg.sender], "Only an artist can call this function");
        _;
    }

    // Constructor
    constructor(address _paymentToken) ERC721("CollaborativeArt", "CA") {
        ownerr = msg.sender;
        paymentToken = IERC20(_paymentToken);
    }

    // Functions for owner
    function addArtist(address _artistAddress, uint256 _ownershipPercentage) external onlyCollaborativeArtOwner {
        require(totalOwnershipPercentage + _ownershipPercentage <= 100, "Total Ownership max 100%");
        Artist memory newArtist = Artist(_artistAddress, _ownershipPercentage, false, 0);
        artistDetails[_artistAddress] = newArtist;
        artists.add(_artistAddress);
        totalOwnershipPercentage += _ownershipPercentage;
        emit ArtistAdded(_artistAddress, _ownershipPercentage);
    }

    function addPhase(string memory _phaseName) external onlyCollaborativeArtOwner {
        phases[_tokenIds.current()].phaseName = _phaseName;
        _tokenIds.increment();
        emit PhaseAdded(_phaseName);
    }

    function addMilestoneToPhase(uint256 _phaseIndex, string memory _description, uint256 _deadline, uint256 _budget) external onlyCollaborativeArtOwner {
        require(_phaseIndex < _tokenIds.current(), "Invalid phase index");
        
        Phase storage phase = phases[_phaseIndex];
        
        // Tambahkan milestone baru ke fase
        uint256 milestoneId = phase.milestoneCount;
        phase.milestones[milestoneId] = Milestone(_description, _deadline, false, _budget);
        phase.totalBudget += _budget;
        
        // Tingkatkan jumlah milestone dalam fase
        phase.milestoneCount++;
        
        emit MilestoneAdded(_phaseIndex, milestoneId, _description);
    }


    // Function to mark milestone as completed
    function markMilestoneAsCompleted(uint256 _phaseIndex, uint256 _milestoneIndex) external onlyCollaborativeArtOwner {
        require(_phaseIndex < _tokenIds.current(), "Invalid phase index");
        
        Phase storage phase = phases[_phaseIndex];
        
        // Periksa apakah indeks milestone yang diberikan valid
        require(_milestoneIndex < phase.milestoneCount, "Invalid milestone index");
        
        // Periksa apakah milestone sudah selesai
        require(!phase.milestones[_milestoneIndex].completed, "Milestone already completed");

        // Tandai milestone sebagai selesai
        phase.milestones[_milestoneIndex].completed = true;

        // Emit event
        emit MilestoneCompleted(_phaseIndex, _milestoneIndex, phase.milestones[_milestoneIndex].description);
    }



    function signContract(bytes calldata _signature) external {
        require(artists.contains(msg.sender), "Must be an artist of the project");
        bytes32 hash = _hashTypedDataV4(
            _domainSeparator(),
            keccak256(abi.encode(
                keccak256("CollaborativeArt(address artist)"),
                msg.sender
            ))
        );
        address signer = ECDSA.recover(hash, _signature);
        require(signer == msg.sender, "Invalid signature");
        artistSigned[msg.sender] = true;
        emit ArtistSigned(msg.sender);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("CollaborativeArt")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    function setArtworkPrice(uint256 _price) external onlyCollaborativeArtOwner {
        artworkPrice = _price;
    }

    function setArtworkExhibition(uint256 _tokenId, string memory _exhibition) external onlyCollaborativeArtOwner {
        require(_exists(_tokenId), "Token does not exist");
        artworkSales[_tokenId].forSale = true;
        artworkSales[_tokenId].price = artworkPrice;
        emit ArtworkExhibited(_tokenId, _exhibition);
    }

    function buyArtwork(uint256 _tokenId) external payable nonReentrant {
        require(artworkSales[_tokenId].forSale, "Artwork not for sale");
        require(msg.value == artworkSales[_tokenId].price, "Incorrect payment amount");
        address artistAddress = ownerOf(_tokenId);
        paymentToken.transfer(artistAddress, msg.value);
        _transfer(artistAddress, msg.sender, _tokenId);
        emit ArtworkSold(_tokenId, msg.value, "Artwork sold");
    }

    function withdrawFunds(uint256 _amount) external onlyArtist nonReentrant {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        payable(msg.sender).transfer(_amount);
    }

    function createDispute(uint256 _disputeId, string memory _description, uint256 _resolutionDeadline, uint256 _arbitrationFee) external onlyArtist {
        require(!disputes[_disputeId].resolved, "Dispute already resolved");

        address[] memory votersTemp; // Gunakan "memory" di sini
        // Inisialisasi votersTemp
        // Lakukan apa yang diperlukan untuk mengisi votersTemp, misalnya melalui penggunaan fungsi lain

        // Salin semua elemen dari votersTemp ke disputes[_disputeId].voters
        for (uint256 i = 0; i < votersTemp.length; i++) {
            disputes[_disputeId].voters.add(votersTemp[i]);
        }

        disputes[_disputeId].description = _description;
        disputes[_disputeId].resolutionDeadline = _resolutionDeadline;
        disputes[_disputeId].arbitrationFee = _arbitrationFee;

        emit DisputeCreated(_disputeId, _description);
    }


    function voteOnDispute(uint256 _disputeId, bool _vote) external onlyArtist {
        require(!disputes[_disputeId].resolved, "Dispute already resolved");
        Dispute storage dispute = disputes[_disputeId];
        require(!dispute.voted[msg.sender], "Already voted");
        dispute.voted[msg.sender] = true;
        dispute.voters.add(msg.sender);
        dispute.totalVotes++;
        if (_vote) {
            dispute.affirmativeVotes++;
        }
        emit DisputeVoted(_disputeId, msg.sender, _vote);
    }

    function resolveDispute(uint256 _disputeId, address _arbitrator) external onlyCollaborativeArtOwner {
        require(!disputes[_disputeId].resolved, "Dispute already resolved");
        Dispute storage dispute = disputes[_disputeId];
        require(block.timestamp <= dispute.resolutionDeadline, "Resolution deadline passed");
        require(dispute.totalVotes > 0, "No votes cast");
        require(dispute.totalVotes >= artists.length() / 2, "Not enough votes to reach consensus");
        dispute.arbitrator = _arbitrator;
        emit DisputeResolved(_disputeId, dispute.decision);
    }

    function setArtworkLicense(uint256 _tokenId, bool _canReproduce, bool _canModify) external onlyCollaborativeArtOwner {
        artworkLicense[_tokenId].canReproduce = _canReproduce;
        artworkLicense[_tokenId].canModify = _canModify;

        emit LicenseSet(_tokenId, msg.sender, _canReproduce, _canModify);
    }


    function setRoyaltyPercentage(uint256 _tokenId, address _artist, uint256 _royaltyPercentage) external onlyCollaborativeArtOwner {
        require(artists.contains(_artist), "Artist not part of the project");
        artworkLicense[_tokenId].royaltyPercentage[_artist] = _royaltyPercentage;
        emit RoyaltySet(_tokenId, _artist, _royaltyPercentage);
    }

    function claimRoyalty(uint256 _tokenId) external {
        require(_exists(_tokenId), "Token does not exist");
        address artist = ownerOf(_tokenId);
        require(artworkLicense[_tokenId].royaltyPercentage[artist] > 0, "No royalty set for this artwork");
        uint256 royaltyAmount = (artworkSales[_tokenId].price * artworkLicense[_tokenId].royaltyPercentage[artist]) / 100;
        paymentToken.transfer(artist, royaltyAmount);
    }

    function setArtworkMetadata(uint256 _tokenId, string memory _metadataURI) external onlyCollaborativeArtOwner {
        _setTokenURI(_tokenId, _metadataURI);
    }

    function rateArtistPerformance(address _artist, uint256 _rating) external onlyCollaborativeArtOwner {
        require(artists.contains(_artist), "Artist not part of the project");
        artistDetails[_artist].performanceRating = _rating;
    }

    function getArtistPerformance(address _artist) external view returns (uint256) {
        require(artists.contains(_artist), "Artist not part of the project");
        return artistDetails[_artist].performanceRating;
    }

    function transferArtworkOwnership(address _from, address _to, uint256 _tokenId) external onlyCollaborativeArtOwner {
        require(ownerOf(_tokenId) == _from, "Not the owner of the artwork");
        _transfer(_from, _to, _tokenId);
        emit OwnershipTransferred(_from, _to);
    }

    function changeArtworkPrice(uint256 _tokenId, uint256 _newPrice) external onlyCollaborativeArtOwner {
        uint256 oldPrice = artworkSales[_tokenId].price;
        artworkSales[_tokenId].price = _newPrice;
        emit PriceChanged(_tokenId, oldPrice, _newPrice);
    }

    function _hashTypedDataV4(bytes32 _domainSeparatore, bytes32 _structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatore, _structHash));
    }
}
