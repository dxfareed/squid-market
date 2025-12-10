;; marketplace-escrow.clar
;; Simple marketplace + escrow pattern in Clarity suitable for Clarinet
;; - Sellers create listings with an id and a price (in micro-STX, uX)
;; - Buyers call `buy` which transfers STX from buyer -> contract (escrow)
;; - Buyer calls `confirm-received` to release funds from escrow -> seller
;; - Seller or buyer can cancel/refund under conditions described below
;;
;; Notes:
;; - Uses `stx-transfer?` and `as-contract` patterns. Buyer must have sufficient
;;   STX and must sign the `buy` transaction so the transfer succeeds.
;; - This is a simple on-chain escrow. Production deployments should include
;;   additional checks (time windows, dispute resolution, off-chain delivery
;;   proofs, reentrancy considerations, and thorough testing).
;;
;; Listing state:
;;  u0 = Active
;;  u1 = Sold (escrowed)
;;  u2 = Completed (released to seller)
;;  u3 = Cancelled (removed/refunded)

(define-map listings
  ((listing-id uint))
  ((seller principal)
   (price uint)
   (state uint)
   (buyer (optional principal))
   (metadata (optional (buff 256)))))

(define-read-only (get-listing (id uint))
  (map-get? listings (tuple (listing-id id))))

(define-public (create-listing (id uint) (price uint) (metadata (optional (buff 256))))
  (begin
    (asserts! (is-eq price u0) (err u100)) ;; prevent zero-priced listings (u100 = custom error code)
    ;; ensure listing doesn't already exist
    (match (map-get? listings (tuple (listing-id id)))
      entry (err u101)
      (ok
        (map-set listings (tuple (listing-id id))
          (tuple (seller tx-sender) (price price) (state u0) (buyer (none)) (metadata metadata)))
        
        ;; Clarity 4 / Epoch 3.0: Log listing creation with principal-destruct info
        (match (principal-destruct? tx-sender)
            success (print { event: "create-listing", id: id, seller: tx-sender, type: (get name success) })
            error (print { event: "create-listing-error", id: id, code: error })
        )

        (ok id)))))

(define-public (cancel-listing (id uint))
  (let ((entry (map-get? listings (tuple (listing-id id)))))
    (match entry
      entry-data
      (let ((seller (get seller entry-data)) (state (get state entry-data)) (buyer (get buyer entry-data)))
        (begin
          (asserts! (is-eq tx-sender seller) (err u102)) ;; only seller can cancel
          (asserts! (is-eq state u0) (err u103)) ;; only active listings can be cancelled
          (map-set listings (tuple (listing-id id))
            (tuple (seller seller) (price (get price entry-data)) (state u3) (buyer (none)) (metadata (get metadata entry-data))))
          (ok true)))
      (err u104))))

(define-public (buy (id uint))
  (let ((entry (map-get? listings (tuple (listing-id id)))))
    (match entry
      entry-data
      (let ((seller (get seller entry-data)) (price (get price entry-data)) (state (get state entry-data)))
        (begin
          (asserts! (is-eq state u0) (err u105)) ;; must be active
          (asserts! (not (is-eq tx-sender seller)) (err u106)) ;; seller cannot buy own listing
          ;; transfer STX from buyer (tx-sender) -> contract principal (as-contract tx-sender)
          (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
          ;; record buyer and set state to Sold (escrowed)
          (map-set listings (tuple (listing-id id))
            (tuple (seller seller) (price price) (state u1) (buyer (some tx-sender)) (metadata (get metadata entry-data))))
          (ok true))))
      (err u104))))

(define-public (confirm-received (id uint))
  (let ((entry (map-get? listings (tuple (listing-id id)))))
    (match entry
      entry-data
      (let ((seller (get seller entry-data)) (price (get price entry-data)) (state (get state entry-data)) (buyer-opt (get buyer entry-data)))
        (match buyer-opt
          buyer
          (begin
            (asserts! (is-eq state u1) (err u107)) ;; must be sold / escrowed
            (asserts! (is-eq tx-sender buyer) (err u108)) ;; only buyer confirms
            ;; transfer STX from contract -> seller
            (try! (as-contract (stx-transfer? price tx-sender seller)))
            ;; mark completed
            (map-set listings (tuple (listing-id id))
              (tuple (seller seller) (price price) (state u2) (buyer (some buyer)) (metadata (get metadata entry-data))))
            (ok true))
          (err u109))))
      (err u104))))

;; allow buyer to request refund before they confirm; seller can refund buyer manually
(define-public (refund-buyer (id uint))
  (let ((entry (map-get? listings (tuple (listing-id id)))))
    (match entry
      entry-data
      (let ((seller (get seller entry-data)) (price (get price entry-data)) (state (get state entry-data)) (buyer-opt (get buyer entry-data)))
        (match buyer-opt
          buyer
          (begin
            (asserts! (is-eq state u1) (err u110)) ;; only when escrowed
            (asserts! (is-eq tx-sender seller) (err u111)) ;; only seller can refund in this simple flow
            ;; send back to buyer
            (try! (as-contract (stx-transfer? price tx-sender buyer)))
            ;; set state cancelled
            (map-set listings (tuple (listing-id id))
              (tuple (seller seller) (price price) (state u3) (buyer (none)) (metadata (get metadata entry-data))))
            (ok true))
          (err u109))))
      (err u104))))

;; convenience read-only utils
(define-read-only (is-active (id uint))
  (match (map-get? listings (tuple (listing-id id)))
    entry (is-eq (get state entry) u0)
    false))

(define-read-only (get-price (id uint))
  (match (map-get? listings (tuple (listing-id id)))
    entry (get price entry)
    (err u104)))

;; End of contract
