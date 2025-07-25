;; CreativeChain: Creative Project Tracking and Artistic Reward System
;; Version: 1.0.0

;; Constants
(define-constant CREATIVE_INCENTIVE_CAPACITY u2800000)
(define-constant BASE_CREATIVE_REWARD u20)
(define-constant ARTIST_BONUS u7)
(define-constant MAX_ARTIST_LEVEL u10)
(define-constant ERR_INVALID_PROJECT_USAGE u1)
(define-constant ERR_NO_CREATIVE_POINTS u2)
(define-constant ERR_INCENTIVE_EXCEEDED u3)
(define-constant BLOCKS_PER_CREATIVE_CYCLE u1440)
(define-constant PORTFOLIO_OPTIMIZATION_MULTIPLIER u3)
(define-constant MIN_OPTIMIZATION_PERIOD u720)
(define-constant EARLY_OPTIMIZATION_PENALTY u12)

;; Data Variables
(define-data-var total-creative-points-awarded uint u0)
(define-data-var total-creative-projects uint u0)
(define-data-var arts-coordinator principal tx-sender)

;; Data Maps
(define-map artist-projects principal uint)
(define-map artist-creative-points principal uint)
(define-map project-start-time principal uint)
(define-map artist-level principal uint)
(define-map artist-last-project principal uint)
(define-map artist-optimized-portfolio principal uint)
(define-map artist-optimization-start-block principal uint)

;; Public Functions
(define-public (start-creative-project (project-complexity uint))
  (let
    (
      (artist tx-sender)
    )
    (asserts! (> project-complexity u0) (err ERR_INVALID_PROJECT_USAGE))
    (map-set project-start-time artist burn-block-height)
    (ok true)
  ))

(define-public (complete-creative-project (project-complexity uint))
  (let
    (
      (artist tx-sender)
      (start-block (default-to u0 (map-get? project-start-time artist)))
      (blocks-creating (- burn-block-height start-block))
      (last-project-block (default-to u0 (map-get? artist-last-project artist)))
      (artist-tier (default-to u0 (map-get? artist-level artist)))
      (capped-tier (if (<= artist-tier MAX_ARTIST_LEVEL) artist-tier MAX_ARTIST_LEVEL))
      (creative-reward (+ BASE_CREATIVE_REWARD (* capped-tier ARTIST_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-creating project-complexity)) (err ERR_INVALID_PROJECT_USAGE))
    
    (map-set artist-projects artist (+ (default-to u0 (map-get? artist-projects artist)) u1))
    (map-set artist-creative-points artist (+ (default-to u0 (map-get? artist-creative-points artist)) creative-reward))
    
    (if (< (- burn-block-height last-project-block) BLOCKS_PER_CREATIVE_CYCLE)
      (map-set artist-level artist (+ artist-tier u1))
      (map-set artist-level artist u1)
    )
    
    (map-set artist-last-project artist burn-block-height)
    (var-set total-creative-projects (+ (var-get total-creative-projects) u1))
    (var-set total-creative-points-awarded (+ (var-get total-creative-points-awarded) creative-reward))
    
    (asserts! (<= (var-get total-creative-points-awarded) CREATIVE_INCENTIVE_CAPACITY) (err ERR_INCENTIVE_EXCEEDED))
    (ok creative-reward)
  ))

(define-public (claim-creative-rewards)
  (let
    (
      (artist tx-sender)
      (point-balance (default-to u0 (map-get? artist-creative-points artist)))
    )
    (asserts! (> point-balance u0) (err ERR_NO_CREATIVE_POINTS))
    (map-set artist-creative-points artist u0)
    (ok point-balance)
  ))

;; Portfolio Optimization Features
(define-public (optimize-creative-portfolio (amount uint))
  (let
    (
      (artist tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_PROJECT_USAGE))
    (asserts! (>= (var-get total-creative-points-awarded) amount) (err ERR_INCENTIVE_EXCEEDED))
    
    (map-set artist-optimized-portfolio artist amount)
    (map-set artist-optimization-start-block artist burn-block-height)
    (var-set total-creative-points-awarded (- (var-get total-creative-points-awarded) amount))
    (ok amount)
  ))

(define-public (complete-portfolio-optimization)
  (let
    (
      (artist tx-sender)
      (optimized-amount (default-to u0 (map-get? artist-optimized-portfolio artist)))
      (optimization-start-block (default-to u0 (map-get? artist-optimization-start-block artist)))
      (blocks-optimized (- burn-block-height optimization-start-block))
      (penalty (if (< blocks-optimized MIN_OPTIMIZATION_PERIOD) (/ (* optimized-amount EARLY_OPTIMIZATION_PENALTY) u100) u0))
      (final-amount (- optimized-amount penalty))
    )
    (asserts! (> optimized-amount u0) (err ERR_NO_CREATIVE_POINTS))
    
    (map-set artist-optimized-portfolio artist u0)
    (map-set artist-optimization-start-block artist u0)
    (var-set total-creative-points-awarded (+ (var-get total-creative-points-awarded) final-amount))
    (ok final-amount)
  ))

;; Read-Only Functions
(define-read-only (get-project-count (user principal))
  (default-to u0 (map-get? artist-projects user)))

(define-read-only (get-creative-point-balance (user principal))
  (default-to u0 (map-get? artist-creative-points user)))

(define-read-only (get-artist-level (user principal))
  (default-to u0 (map-get? artist-level user)))

(define-read-only (get-creative-program-stats)
  {
    total-creative-projects: (var-get total-creative-projects),
    total-creative-points-awarded: (var-get total-creative-points-awarded)
  })

;; Private Functions
(define-private (is-arts-coordinator)
  (is-eq tx-sender (var-get arts-coordinator)))