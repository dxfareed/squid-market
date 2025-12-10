;; bob-market.clar
;; "Bob Market" - Reputation-based Marketplace with Expiry

(define-map listings
  ((listing-id uint))
  ((seller principal)
   (price uint)
   (state uint) ;; 0=Active, 1=Sold, 2=Completed, 3=Cancelled
   (buyer (optional principal))
   (metadata (optional (buff 256)))
   (expiry uint) ;; Block height when listing expires
  ))

(define-map reputation ((user principal)) ((score uint)))

(define-read-only (get-listing (id uint))
  (map-get? listings (tuple (listing-id id))))

(define-read-only (get-reputation (user principal))
  (default-to u0 (get score (map-get? reputation (tuple (user user))))))

(define-public (create-listing (id uint) (price uint) (metadata (optional (buff 256))) (expiry uint))
  (begin
    (asserts! (is-eq price u0) (err u100))
    (asserts! (> expiry block-height) (err u112)) ;; expiry must be in future
    (match (map-get? listings (tuple (listing-id id)))
      entry (err u101)
      (ok
        (map-set listings (tuple (listing-id id))
          (tuple (seller tx-sender) (price price) (state u0) (buyer (none)) (metadata metadata) (expiry expiry)))
        
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
      (let ((seller (get seller entry-data)) (state (get state entry-data)))
        (begin
          (asserts! (is-eq tx-sender seller) (err u102))
          (asserts! (is-eq state u0) (err u103))
          (map-set listings (tuple (listing-id id))
            (merge entry-data (tuple (state u3))))
          (ok true)))
      (err u104))))

(define-public (buy (id uint))
  (let ((entry (map-get? listings (tuple (listing-id id)))))
    (match entry
      entry-data
      (let ((seller (get seller entry-data)) (price (get price entry-data)) (state (get state entry-data)) (expiry (get expiry entry-data)))
        (begin
          (asserts! (is-eq state u0) (err u105))
          (asserts! (<= block-height expiry) (err u113)) ;; Check expiry
          (asserts! (not (is-eq tx-sender seller)) (err u106))
          
          (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
          
          (map-set listings (tuple (listing-id id))
            (merge entry-data (tuple (state u1) (buyer (some tx-sender)))))
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
            (asserts! (is-eq state u1) (err u107))
            (asserts! (is-eq tx-sender buyer) (err u108))
            
            (try! (as-contract (stx-transfer? price tx-sender seller)))
            
            ;; Increment Seller Reputation
            (let ((current-rep (get-reputation seller)))
                (map-set reputation (tuple (user seller)) (tuple (score (+ current-rep u1))))
            )

            (map-set listings (tuple (listing-id id))
              (merge entry-data (tuple (state u2))))
            (ok true))
          (err u109))))
      (err u104))))

(define-public (refund-buyer (id uint))
  (let ((entry (map-get? listings (tuple (listing-id id)))))
    (match entry
      entry-data
      (let ((seller (get seller entry-data)) (price (get price entry-data)) (state (get state entry-data)) (buyer-opt (get buyer entry-data)))
        (match buyer-opt
          buyer
          (begin
            (asserts! (is-eq state u1) (err u110))
            (asserts! (is-eq tx-sender seller) (err u111))
            
            (try! (as-contract (stx-transfer? price tx-sender buyer)))
            
            (map-set listings (tuple (listing-id id))
              (merge entry-data (tuple (state u3) (buyer (none)))))
            (ok true))
          (err u109))))
      (err u104))))

(define-read-only (is-active (id uint))
  (match (map-get? listings (tuple (listing-id id)))
    entry (is-eq (get state entry) u0)
    false))

(define-read-only (get-price (id uint))
  (match (map-get? listings (tuple (listing-id id)))
    entry (get price entry)
    (err u104)))


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
