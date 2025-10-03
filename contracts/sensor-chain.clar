;; Title: SensorChain - Decentralized IoT Data Marketplace
;;
;; Summary:
;; A trustless marketplace protocol enabling IoT device owners to monetize real-time sensor data
;; through stake-backed registrations, subscription-based access, and community-driven validation.
;;
;; Description:
;; SensorChain transforms IoT devices into revenue-generating assets on Bitcoin Layer 2. Device
;; operators stake STX to register sensors, set their own pricing models, and earn from data consumers
;; who subscribe for real-time access. A reputation system powered by independent validators ensures
;; data integrity, while automated payment distribution handles fees transparently. Built for smart
;; cities, environmental monitoring, supply chain tracking, and any application requiring verified,
;; decentralized sensor data with cryptographic proof of authenticity.

;; ERROR CODES

(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-SENSOR-OFFLINE (err u105))
(define-constant ERR-DATA-EXPIRED (err u106))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u107))

;; DATA VARIABLES

(define-data-var contract-owner principal tx-sender)
(define-data-var sensor-counter uint u0)
(define-data-var data-entry-counter uint u0)
(define-data-var platform-fee uint u200) ;; 2% in basis points
(define-data-var data-retention-period uint u52560) ;; ~1 year in blocks

;; CONSTANTS

(define-constant MIN-STAKE u10000)
(define-constant BASIS-POINTS u10000)
(define-constant DATA-FRESHNESS-WINDOW u144) ;; ~1 day in blocks
(define-constant MAX-SENSORS-PER-OWNER u100)

;; Sensor type definitions
(define-constant TYPE-TEMPERATURE u1)
(define-constant TYPE-HUMIDITY u2)
(define-constant TYPE-AIR-QUALITY u3)
(define-constant TYPE-MOTION u4)
(define-constant TYPE-SOUND u5)
(define-constant TYPE-LIGHT u6)

;; DATA MAPS

(define-map sensors
  uint
  {
    owner: principal,
    device-id: (string-ascii 50),
    sensor-type: uint,
    location: (string-ascii 100),
    description: (string-ascii 200),
    price-per-query: uint,
    stake-amount: uint,
    is-active: bool,
    last-update: uint,
    total-queries: uint,
    reputation-score: uint
  }
)

(define-map sensor-data
  uint
  {
    sensor-id: uint,
    timestamp: uint,
    data-value: int,
    data-hash: (buff 32),
    validator: (optional principal),
    is-verified: bool
  }
)

(define-map user-balances 
  principal 
  uint
)

(define-map subscriptions
  { subscriber: principal, sensor-id: uint }
  { expires-at: uint, queries-remaining: uint, total-paid: uint }
)

(define-map owner-sensor-count 
  principal 
  uint
)

;; VALIDATION HELPERS

(define-private (is-valid-device-id (device-id (string-ascii 50)))
  (and (> (len device-id) u5) (<= (len device-id) u50))
)

(define-private (is-valid-location (location (string-ascii 100)))
  (and (> (len location) u5) (<= (len location) u100))
)

(define-private (is-valid-sensor-type (sensor-type uint))
  (and (>= sensor-type TYPE-TEMPERATURE) (<= sensor-type TYPE-LIGHT))
)

(define-private (is-valid-description (desc (string-ascii 200)))
  (and (> (len desc) u10) (<= (len desc) u200))
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-sensor (sensor-id uint))
  (map-get? sensors sensor-id)
)

(define-read-only (get-sensor-data (data-entry-id uint))
  (map-get? sensor-data data-entry-id)
)

(define-read-only (get-subscription (subscriber principal) (sensor-id uint))
  (map-get? subscriptions { subscriber: subscriber, sensor-id: sensor-id })
)

(define-read-only (get-sensor-count)
  (var-get sensor-counter)
)

(define-read-only (is-sensor-active (sensor-id uint))
  (match (map-get? sensors sensor-id)
    sensor (and 
             (get is-active sensor) 
             (<= (- stacks-block-height (get last-update sensor)) DATA-FRESHNESS-WINDOW))
    false
  )
)

;; BALANCE MANAGEMENT

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender (+ (get-balance tx-sender) amount))
    (ok true)
  )
)

(define-public (withdraw (amount uint))
  (let (
    (user-balance (get-balance tx-sender))
  )
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-FUNDS)
    (map-set user-balances tx-sender (- user-balance amount))
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok true)
  )
)

;; SENSOR REGISTRATION & MANAGEMENT

(define-public (register-sensor
    (device-id (string-ascii 50))
    (sensor-type uint)
    (location (string-ascii 100))
    (description (string-ascii 200))
    (price-per-query uint)
    (stake-amount uint))
  (let (
    (sensor-id (+ (var-get sensor-counter) u1))
    (owner-count (default-to u0 (map-get? owner-sensor-count tx-sender)))
    (user-balance (get-balance tx-sender))
  )
    ;; Validate inputs
    (asserts! (is-valid-device-id device-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-sensor-type sensor-type) ERR-INVALID-INPUT)
    (asserts! (is-valid-location location) ERR-INVALID-INPUT)
    (asserts! (is-valid-description description) ERR-INVALID-INPUT)
    (asserts! (> price-per-query u0) ERR-INVALID-INPUT)
    (asserts! (>= stake-amount MIN-STAKE) ERR-INVALID-INPUT)
    (asserts! (< owner-count MAX-SENSORS-PER-OWNER) ERR-INVALID-INPUT)
    (asserts! (>= user-balance stake-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Deduct stake from owner balance
    (map-set user-balances tx-sender (- user-balance stake-amount))
    
    ;; Register the sensor
    (map-set sensors sensor-id {
      owner: tx-sender,
      device-id: device-id,
      sensor-type: sensor-type,
      location: location,
      description: description,
      price-per-query: price-per-query,
      stake-amount: stake-amount,
      is-active: true,
      last-update: stacks-block-height,
      total-queries: u0,
      reputation-score: u100
    })
    
    ;; Update counters
    (var-set sensor-counter sensor-id)
    (map-set owner-sensor-count tx-sender (+ owner-count u1))
    
    (ok sensor-id)
  )
)

(define-public (deactivate-sensor (sensor-id uint))
  (let (
    (sensor (unwrap! (map-get? sensors sensor-id) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR-UNAUTHORIZED)
    
    ;; Return stake to owner
    (map-set user-balances tx-sender 
             (+ (get-balance tx-sender) (get stake-amount sensor)))
    
    ;; Mark sensor as inactive
    (map-set sensors sensor-id (merge sensor { is-active: false }))
    
    (ok true)
  )
)

;; DATA SUBMISSION & VERIFICATION

(define-public (submit-data (sensor-id uint) (data-value int) (data-hash (buff 32)))
  (let (
    (sensor (unwrap! (map-get? sensors sensor-id) ERR-NOT-FOUND))
    (data-entry-id (+ (var-get data-entry-counter) u1))
  )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR-UNAUTHORIZED)
    (asserts! (get is-active sensor) ERR-SENSOR-OFFLINE)
    
    ;; Store data entry
    (map-set sensor-data data-entry-id {
      sensor-id: sensor-id,
      timestamp: stacks-block-height,
      data-value: data-value,
      data-hash: data-hash,
      validator: none,
      is-verified: false
    })
    
    ;; Update sensor metadata
    (map-set sensors sensor-id (merge sensor { last-update: stacks-block-height }))
    (var-set data-entry-counter data-entry-id)
    
    (ok data-entry-id)
  )
)

(define-public (verify-data (data-entry-id uint) (is-valid bool))
  (let (
    (data-entry (unwrap! (map-get? sensor-data data-entry-id) ERR-NOT-FOUND))
    (sensor (unwrap! (map-get? sensors (get sensor-id data-entry)) ERR-NOT-FOUND))
  )
    ;; Validators cannot verify their own sensors
    (asserts! (not (is-eq tx-sender (get owner sensor))) ERR-UNAUTHORIZED)
    (asserts! (is-none (get validator data-entry)) ERR-ALREADY-EXISTS)
    
    ;; Record verification
    (map-set sensor-data data-entry-id (merge data-entry {
      validator: (some tx-sender),
      is-verified: is-valid
    }))
    
    ;; Adjust sensor reputation
    (let (
      (current-reputation (get reputation-score sensor))
      (new-reputation (if is-valid 
                        (if (< current-reputation u100) (+ current-reputation u1) current-reputation)
                        (if (>= current-reputation u5) (- current-reputation u5) u0)))
    )
      (map-set sensors (get sensor-id data-entry)
               (merge sensor { reputation-score: new-reputation }))
    )
    
    (ok true)
  )
)

;; SUBSCRIPTION & DATA ACCESS

(define-public (subscribe-to-sensor (sensor-id uint) (duration-blocks uint) (max-queries uint))
  (let (
    (sensor (unwrap! (map-get? sensors sensor-id) ERR-NOT-FOUND))
    (total-cost (* (get price-per-query sensor) max-queries))
    (platform-fee-amount (/ (* total-cost (var-get platform-fee)) BASIS-POINTS))
    (owner-payment (- total-cost platform-fee-amount))
    (subscriber-balance (get-balance tx-sender))
  )
    (asserts! (get is-active sensor) ERR-SENSOR-OFFLINE)
    (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)
    (asserts! (> max-queries u0) ERR-INVALID-INPUT)
    (asserts! (>= subscriber-balance total-cost) ERR-INSUFFICIENT-FUNDS)
    
    ;; Process payment
    (map-set user-balances tx-sender (- subscriber-balance total-cost))
    (map-set user-balances (get owner sensor)
             (+ (get-balance (get owner sensor)) owner-payment))
    (map-set user-balances (var-get contract-owner)
             (+ (get-balance (var-get contract-owner)) platform-fee-amount))
    
    ;; Create subscription
    (map-set subscriptions { subscriber: tx-sender, sensor-id: sensor-id } {
      expires-at: (+ stacks-block-height duration-blocks),
      queries-remaining: max-queries,
      total-paid: total-cost
    })
    
    (ok true)
  )
)

(define-public (query-sensor-data (sensor-id uint))
  (let (
    (sensor (unwrap! (map-get? sensors sensor-id) ERR-NOT-FOUND))
    (subscription (unwrap! (map-get? subscriptions { subscriber: tx-sender, sensor-id: sensor-id }) 
                           ERR-NOT-FOUND))
  )
    (asserts! (get is-active sensor) ERR-SENSOR-OFFLINE)
    (asserts! (<= stacks-block-height (get expires-at subscription)) ERR-SUBSCRIPTION-EXPIRED)
    (asserts! (> (get queries-remaining subscription) u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (<= (- stacks-block-height (get last-update sensor)) DATA-FRESHNESS-WINDOW) ERR-DATA-EXPIRED)
    
    ;; Decrement query allowance
    (map-set subscriptions { subscriber: tx-sender, sensor-id: sensor-id }
             (merge subscription { queries-remaining: (- (get queries-remaining subscription) u1) }))
    
    ;; Update analytics
    (map-set sensors sensor-id 
             (merge sensor { total-queries: (+ (get total-queries sensor) u1) }))
    
    (ok true)
  )
)

;; ADMIN FUNCTIONS

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-INPUT) ;; Maximum 10%
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (set-data-retention (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (> new-period u0) ERR-INVALID-INPUT)
    (var-set data-retention-period new-period)
    (ok true)
  )
)