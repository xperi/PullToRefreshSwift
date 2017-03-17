//
//  PullToRefreshConst.swift
//  PullToRefreshSwift
//
//  Created by Yuji Hato on 12/11/14.
//
import UIKit

open class PullToRefreshView: UIView {
    enum PullToRefreshState {
        case normal
        case pulling
        case refreshing
    }
    
    // MARK: Variables
    let contentOffsetKeyPath = "contentOffset"
    var kvoContext = ""
    
    fileprivate var options: PullToRefreshOption!
    fileprivate var backgroundView: UIView!
    fileprivate var arrow: UIImageView!
    fileprivate var indicator: UIActivityIndicatorView!
    fileprivate var scrollViewBounces: Bool = false
    fileprivate var scrollViewInsets: UIEdgeInsets = UIEdgeInsets.zero
    fileprivate var previousOffset: CGFloat = 0
    fileprivate var refreshCompletion: (() -> ()) = {}
    
    var state: PullToRefreshState = PullToRefreshState.normal {
        didSet {
            if self.state == oldValue {
                return
            }
            switch self.state {
            case .normal:
                stopAnimating()
            case .refreshing:
                startAnimating()
            default:
                break
            }
        }
    }
    
    var enable: Bool = true
    
    // MARK: UIView
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public convenience init(options: PullToRefreshOption, frame: CGRect, refreshCompletion :@escaping (() -> ())) {
        self.init(frame: frame)
        self.options = options
        self.refreshCompletion = refreshCompletion

        self.backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        self.backgroundView.backgroundColor = self.options.backgroundColor
        self.backgroundView.autoresizingMask = UIViewAutoresizing.flexibleWidth
        self.addSubview(backgroundView)
        
        self.arrow = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        self.arrow.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        
        self.arrow.image = UIImage(named: PullToRefreshConst.imageName, in: Bundle(for: type(of: self)), compatibleWith: nil)
        self.addSubview(arrow)
        
        self.indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        self.indicator.bounds = self.arrow.bounds
        self.indicator.autoresizingMask = self.arrow.autoresizingMask
        self.indicator.hidesWhenStopped = true
        self.indicator.color = options.indicatorColor
        self.addSubview(indicator)
        
        self.autoresizingMask = .flexibleWidth
    }
   
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.arrow.center = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
        self.indicator.center = self.arrow.center
    }
    
    open override func willMove(toSuperview superView: UIView!) {
        
        superview?.removeObserver(self, forKeyPath: contentOffsetKeyPath, context: &kvoContext)
        
        if let scrollView = superView as? UIScrollView {
            scrollView.addObserver(self, forKeyPath: contentOffsetKeyPath, options: .initial, context: &kvoContext)
        }
    }
    
    deinit {
        if let scrollView = superview as? UIScrollView {
            scrollView.removeObserver(self, forKeyPath: contentOffsetKeyPath, context: &kvoContext)
        }
    }
    
    // MARK: KVO
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if (context == &kvoContext && keyPath == contentOffsetKeyPath) {
            if let scrollView = object as? UIScrollView, enable {
                
                // Debug
                //println(scrollView.contentOffset.y)
                
                let offsetWithoutInsets = self.previousOffset + self.scrollViewInsets.top
                
                // Update the content inset for fixed section headers
                if self.options.fixedSectionHeader && self.state == .refreshing {
                    if (scrollView.contentOffset.y > 0) {
                        scrollView.contentInset = UIEdgeInsets.zero
                    }
                    return
                }
                
                // Alpha set
                if PullToRefreshConst.alpha {
                    var alpha = fabs(offsetWithoutInsets) / (self.frame.size.height + 30)
                    if alpha > 0.8 {
                        alpha = 0.8
                    }
                    self.arrow.alpha = alpha
                }
                
                // Backgroundview frame set
                if PullToRefreshConst.fixedTop {
                    if PullToRefreshConst.height < fabs(offsetWithoutInsets) {
                        self.backgroundView.frame.size.height = fabs(offsetWithoutInsets)
                    } else {
                        self.backgroundView.frame.size.height =  PullToRefreshConst.height
                    }
                } else {
                    self.backgroundView.frame.size.height = PullToRefreshConst.height + fabs(offsetWithoutInsets)
                    self.backgroundView.frame.origin.y = -fabs(offsetWithoutInsets)
                }
                
                // Pulling State Check
                if (offsetWithoutInsets < -self.frame.size.height) {
                    
                    // pulling or refreshing
                    if (scrollView.isDragging == false && self.state != .refreshing) {
                        self.state = .refreshing
                    } else if (self.state != .refreshing) {
                        self.arrowRotation()
                        self.state = .pulling
                    }
                } else if (self.state != .refreshing && offsetWithoutInsets < 0) {
                    // normal
                    self.arrowRotationBack()
                }
                self.previousOffset = scrollView.contentOffset.y
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: private
    
    fileprivate func startAnimating() {
        self.indicator.startAnimating()
        self.arrow.isHidden = true
        
        if let scrollView = superview as? UIScrollView {
            scrollViewBounces = scrollView.bounces
            scrollViewInsets = scrollView.contentInset
            
            var insets = scrollView.contentInset
            insets.top += self.frame.size.height
            scrollView.contentOffset.y = self.previousOffset
            scrollView.bounces = false
            UIView.animate(withDuration: PullToRefreshConst.animationDuration, delay: 0, options:[], animations: {
                scrollView.contentInset = insets
                scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: -insets.top)
                }, completion: {finished in
                    if self.options.autoStopTime != 0 {
                        let time = DispatchTime.now() + Double(Int64(self.options.autoStopTime * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                        DispatchQueue.main.asyncAfter(deadline: time) {
                            self.state = .normal
                        }
                    }
                    self.refreshCompletion()
            })
        }
    }
    
    fileprivate func stopAnimating() {
        self.indicator.stopAnimating()
        self.arrow.transform = CGAffineTransform.identity
        self.arrow.isHidden = false
        
        if let scrollView = superview as? UIScrollView {
            scrollView.bounces = self.scrollViewBounces
            UIView.animate(withDuration: PullToRefreshConst.animationDuration, animations: { () -> Void in
                scrollView.contentInset = self.scrollViewInsets
                }, completion: { (Bool) -> Void in
                    
            }) 
        }
    }
    
    fileprivate func arrowRotation() {
        UIView.animate(withDuration: 0.2, delay: 0, options:[], animations: {
            // -0.0000001 for the rotation direction control
            self.arrow.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI-0.0000001))
        }, completion:nil)
    }
    
    fileprivate func arrowRotationBack() {
        UIView.animate(withDuration: 0.2, delay: 0, options:[], animations: {
            self.arrow.transform = CGAffineTransform.identity
            }, completion:nil)
    }
}
