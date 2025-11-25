;; Allowlist / Whitelist Manager for NFT mint access control
;; - Supports multiple phases (e.g. presale, friends-and-family, public)
;; - Each phase can have:
;;   - start and end block height
;;   - per-address mint limit
;;   - optional price per NFT
;; - Contract tracks which principals are allowed in which phase
;; - NFT contracts call `can-mint?` to verify access before minting

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PHASE-NOT-FOUND (err u101))
(define-constant ERR-PHASE-ACTIVE (err u102))
(define-constant ERR-ALREADY-ALLOWED (err u103))
(define-constant ERR-NOT-ALLOWED (err u104))
(define-constant ERR-MINT-LIMIT (err u105))
(define-constant ERR-PHASE-INACTIVE (err u106))

(define-data-var contract-owner principal tx-sender)

(define-map phases
  { id: uint }
  {
    id: uint,
    name: (string-ascii 32),
    start-height: uint,
    end-height: uint,
    max-per-address: uint,
    price: uint
  }
)

(define-map allowlist
  { phase-id: uint, user: principal }
  {
    phase-id: uint,
    user: principal,
    minted: uint
  }
)

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

(define-private (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok new-owner)
  )
)

(define-public (create-phase
  (id uint)
  (name (string-ascii 32))
  (start-height uint)
  (end-height uint)
  (max-per-address uint)
  (price uint)
)
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
    (map-set phases { id: id }
      {
        id: id,
        name: name,
        start-height: start-height,
        end-height: end-height,
        max-per-address: max-per-address,
        price: price
      }
    )
    (ok id)
  )
)

(define-public (update-phase
  (id uint)
  (start-height uint)
  (end-height uint)
  (max-per-address uint)
  (price uint)
)
  (let ((existing (map-get? phases { id: id })))
    (match existing
      phase
        (begin
          (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
          (map-set phases { id: id }
            {
              id: id,
              name: (get name phase),
              start-height: start-height,
              end-height: end-height,
              max-per-address: max-per-address,
              price: price
            }
          )
          (ok id)
        )
      (begin (ERR-PHASE-NOT-FOUND))
    )
  )
)

(define-public (add-to-allowlist (phase-id uint) (user principal))
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
    (let ((existing (map-get? allowlist { phase-id: phase-id, user: user })))
      (match existing
        some-entry (ERR-ALREADY-ALLOWED)
        (begin
          (map-set allowlist { phase-id: phase-id, user: user }
            { phase-id: phase-id, user: user, minted: u0 })
          (ok true)
        )
      )
    )
  )
)

(define-public (remove-from-allowlist (phase-id uint) (user principal))
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
    (let ((existing (map-get? allowlist { phase-id: phase-id, user: user })))
      (match existing
        some-entry
          (begin
            (map-delete allowlist { phase-id: phase-id, user: user })
            (ok true)
          )
        (ERR-NOT-ALLOWED)
      )
    )
  )
)

(define-read-only (get-phase (id uint))
  (ok (map-get? phases { id: id }))
)

(define-read-only (get-allowlist-entry (phase-id uint) (user principal))
  (ok (map-get? allowlist { phase-id: phase-id, user: user }))
)

(define-read-only (is-active-phase (phase-id uint))
  (let ((maybe-phase (map-get? phases { id: phase-id })))
    (match maybe-phase
      phase
        (let
          ((current-height (block-height))
           (start (get start-height phase))
           (end (get end-height phase)))
          (ok (and (>= current-height start) (<= current-height end)))
        )
      (ERR-PHASE-NOT-FOUND)
    )
  )
)

(define-read-only (can-mint?
  (phase-id uint)
  (user principal)
  (quantity uint)
)
  (let (
    (maybe-phase (map-get? phases { id: phase-id }))
    (entry (map-get? allowlist { phase-id: phase-id, user: user }))
  )
    (match maybe-phase
      phase
        (begin
          (let
            ((current-height (block-height))
             (start (get start-height phase))
             (end (get end-height phase)))
            (if (and (>= current-height start) (<= current-height end))
              (match entry
                e
                  (let
                    ((max-per (get max-per-address phase))
                     (already (get minted e))
                     (new-total (+ already quantity)))
                    (if (<= new-total max-per)
                      (ok { allowed: true,
                            remaining: (- max-per new-total),
                            price: (get price phase) })
                      ERR-MINT-LIMIT
                    )
                  )
                ERR-NOT-ALLOWED
              )
              ERR-PHASE-INACTIVE
            )
          )
        )
      ERR-PHASE-NOT-FOUND
    )
  )
)

(define-public (mark-minted
  (phase-id uint)
  (user principal)
  (quantity uint)
)
  (let ((entry (map-get? allowlist { phase-id: phase-id, user: user })))
    (match entry
      e
        (let ((new-total (+ (get minted e) quantity)))
          (map-set allowlist { phase-id: phase-id, user: user }
            {
              phase-id: phase-id,
              user: user,
              minted: new-total
            }
          )
          (ok new-total)
        )
      ERR-NOT-ALLOWED
    )
  )
)

;; Simple helper for NFT contracts: checks and marks mint in one call
(define-public (check-and-consume
  (phase-id uint)
  (user principal)
  (quantity uint)
)
  (let ((check (can-mint? phase-id user quantity)))
    (match check
      result
        (begin
          (try! (mark-minted phase-id user quantity))
          (ok result)
        )
      check
    )
  )
)
