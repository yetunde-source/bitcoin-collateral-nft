;; Title: Bitcoin Collateral NFT (BCNFT)
;; 
;; Summary:
;; A sophisticated NFT protocol that enables the creation of Bitcoin-backed NFTs with 
;; built-in collateralization, staking mechanics, and a decentralized marketplace.
;;
;; Description:
;; This smart contract implements a novel NFT system where each token is backed by 
;; Bitcoin through Stacks' native STX collateral. The protocol features:
;;   - Collateralized NFT minting with dynamic ratios
;;   - Secure ownership and transfer mechanisms
;;   - Integrated decentralized marketplace
;;   - Staking system with yield generation
;;   - Automated reward distribution
;;
;; The protocol maintains high security standards through:
;;   - Minimum collateral requirements
;;   - Protected admin functions
;;   - Secure fund management
;;   - Automated yield calculations
;;

;; Constants

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1001))
(define-constant ERR-INVALID-PARAMETERS (err u1002))
(define-constant ERR-TOKEN-NOT-FOUND (err u1003))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1004))
(define-constant ERR-LISTING-EXISTS (err u1005))
(define-constant ERR-LISTING-NOT-FOUND (err u1006))
(define-constant ERR-TRANSFER-FAILED (err u1007))
(define-constant ERR-ALREADY-STAKED (err u1008))
(define-constant ERR-NOT-STAKED (err u1009))

;; NFT Definition

(define-non-fungible-token bitcoin-backed-nft uint)

;; Data Variables

(define-data-var total-supply uint u0)
(define-data-var protocol-fee uint u25)  ;; 2.5% fee in basis points
(define-data-var min-collateral-ratio uint u150)  ;; 150% minimum collateral ratio
(define-data-var yield-rate uint u50)  ;; 5% annual yield rate in basis points

;; Data Maps

(define-map token-metadata 
    { token-id: uint }
    { 
        creator: principal,
        uri: (string-ascii 256),
        collateral-amount: uint,
        is-staked: bool,
        stake-start-height: uint
    }
)

(define-map token-listings 
    { token-id: uint }
    { 
        price: uint, 
        seller: principal, 
        is-active: bool 
    }
)

(define-map staking-rewards 
    { token-id: uint }
    {
        accumulated-yield: uint,
        last-claim-height: uint
    }
)

;; Utility Functions

(define-private (is-owner-or-authorized (token-id uint))
    (let 
        ((metadata (unwrap! (map-get? token-metadata { token-id: token-id }) false))
         (owner (nft-get-owner? bitcoin-backed-nft token-id)))
        (or 
            (is-eq tx-sender CONTRACT-OWNER)
            (and owner (is-eq tx-sender (unwrap-panic owner)))
        )
    )
)

;; Core NFT Functions

(define-public (mint-nft 
    (uri (string-ascii 256)) 
    (collateral-amount uint)
)
    (let 
        ((new-token-id (+ (var-get total-supply) u1))
         (min-collateral (/ (* (var-get min-collateral-ratio) collateral-amount) u100)))
        (asserts! (> (len uri) u0) ERR-INVALID-PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) min-collateral) ERR-INSUFFICIENT-FUNDS)
        
        (try! (stx-transfer? min-collateral tx-sender (as-contract tx-sender)))
        (try! (nft-mint? bitcoin-backed-nft new-token-id tx-sender))
        
        (map-set token-metadata 
            { token-id: new-token-id }
            { 
                creator: tx-sender,
                uri: uri,
                collateral-amount: collateral-amount,
                is-staked: false,
                stake-start-height: u0
            }
        )
        
        (var-set total-supply new-token-id)
        (ok new-token-id)
    )
)