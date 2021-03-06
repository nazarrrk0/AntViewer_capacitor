//
//  PlayerController.swift
//  viewer-module
//
//  Created by Mykola Vaniurskyi on 12/5/18.
//  Copyright © 2018 Mykola Vaniurskyi. All rights reserved.
//

import UIKit
import AVKit
import AntViewerExt

private let maxTextLength = 250
private let maxUserNameLength = 50

class PlayerController: UIViewController {
  
  private var player: Player!
  
  @IBOutlet weak var portraitMessageBottomSpace: NSLayoutConstraint!
  @IBOutlet var landscapeMessageBottomSpace: NSLayoutConstraint!
  @IBOutlet weak var messageHeight: NSLayoutConstraint!
  @IBOutlet private var liveLabel: UILabel!
  @IBOutlet weak var liveLabelWidth: NSLayoutConstraint! {
    didSet {
      liveLabelWidth.constant = videoContent is VOD ? 0 : 36
    }
  }

  //MARK: - chat field staff
  @IBOutlet weak var bottomContainerView: UIView!
  @IBOutlet weak var bottomContainerViewHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var chatTextView: IQTextView! {
    didSet {
      chatTextView.placeholder = LocalizedStrings.chatDisabled.localized
    }
  }
  @IBOutlet  var chatTextViewHolderView: UIView!
  @IBOutlet  var chatTextViewHolderViewLeading: NSLayoutConstraint!
  @IBOutlet var chatTextViewTrailing: NSLayoutConstraint!
  @IBOutlet  var bottomContainerLeading: NSLayoutConstraint!
  @IBOutlet  var bottomContainerTrailing: NSLayoutConstraint!
  @IBOutlet  var bottomContainerLandscapeTop: NSLayoutConstraint!
  @IBOutlet  var bottomContainerPortraitTop: NSLayoutConstraint!
  fileprivate var isBottomContainerHidedByUser = false
  private var bottomContainerGradientLayer: CAGradientLayer = {
    let gradient = CAGradientLayer()
    gradient.colors = [UIColor.gradientDark.withAlphaComponent(0).cgColor,
                       UIColor.gradientDark.withAlphaComponent(0).cgColor,
                       UIColor.gradientDark.withAlphaComponent(0.5).cgColor,
                       UIColor.gradientDark.withAlphaComponent(0.6).cgColor
                      ]
    gradient.locations = [0, 0.33, 0.44, 1]
    return gradient
  }()
  //MARK:  -

  //MARK: - new chat flow
  @IBOutlet var chatContainerView: UIView!
  @IBOutlet var chatContainerViewLandscapeLeading: NSLayoutConstraint!
  lazy var chatController: ChatViewController = {
    let vc = ChatViewController(nibName: "ChatViewController", bundle: Bundle(for: type(of: self)))
    vc.videoContent = videoContent
    vc.onTableViewTapped = { [weak self] in
      self?.view.endEditing(false)
      if OrientationUtility.isLandscape {
        self?.onVideoTapped(shouldCheckLocation: false)
      }
    }
    vc.handleTableViewSwipeGesture = { [weak self] in
      self?.handleSwipe(isRightDirection: false)
    }
    return vc
  }()
  //MARK: -

  //MARK: - curtain staff
  @IBOutlet var skipCurtainButton: LocalizedButton!
  lazy var skipCurtainButtonDebouncer = Debouncer(delay: 7)
  var currentCurtain: CurtainRange?
  var shouldShowSkipButton = true
  //MARK: -

  @IBOutlet weak var sendButton: UIButton!
  @IBOutlet weak var videoContainerView: AVPlayerView! {
    didSet {
      videoContainerView.contentMode = .scaleAspectFit
      videoContainerView.load(url: URL(string: videoContent.thumbnailUrl), placeholder: nil)
    }
  }

  //MARK: - video controls
  @IBOutlet weak var videoControlsView: UIView!
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var nextButton: UIButton!
  @IBOutlet weak var previousButton: UIButton!
  @IBOutlet var cancelButton: LocalizedButton!
  @IBOutlet var fullScreenButtons: [UIButton]!
  @IBOutlet var thanksForWatchingLabel: UILabel!
  @IBOutlet var liveDurationLabel: UILabel!
  private var isAutoplayMode = false
  private lazy var backgroundShape = CAShapeLayer()
  private lazy var progressShape = CAShapeLayer()
  lazy var autoplayDebouncer = Debouncer(delay: 4.5)
  //MARK: -
  
  
  @IBOutlet weak var pollContainerView: UIView!
  @IBOutlet weak var durationView: UIView! {
    didSet {
      durationView.isHidden = !(videoContent is VOD)
    }
  }
  
  var activeSpendTime: Double = 0 {
    didSet {
      Statistic.save(action: .close(span: Int(activeSpendTime)), for: videoContent)
    }
  }
  
  var dataSource: DataSource!
  fileprivate var streamTimer: Timer?
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return OrientationUtility.isLandscape ? .top : .bottom
  }
  

  @IBOutlet weak var editProfileButton: UIButton! {
    didSet {
      editProfileButton.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
    }
  }
  @IBOutlet weak var shareButton: UIButton! {
     didSet {
       shareButton.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
     }
   }
  
  @IBOutlet weak var editProfileContainerView: UIView!
  
  @IBOutlet weak var durationLabel: UILabel! {
    didSet {
      if let video = videoContent as? VOD {
        durationLabel.text = video.duration
      }
    }
  }

  @IBOutlet weak var landscapeBroadcasterProfileImage: CacheImageView! {
    didSet {
      landscapeBroadcasterProfileImage.load(url: URL(string: videoContent.broadcasterPicUrl), placeholder: UIImage.image("avaPic"))
    }
  }
  
  @IBOutlet weak var startLabel: UILabel!

  @IBOutlet weak var viewersCountLabel: UILabel! {
    didSet {
      viewersCountLabel.text = videoContent.viewsCount.formatUsingAbbrevation()
    }
  }

  @IBOutlet var viewersCountView: UIView!

  @IBOutlet weak var portraitSeekSlider: CustomSlide! {
    didSet {
      if let video = videoContent as? VOD {
        portraitSeekSlider.isHidden = false
        self.portraitSeekSlider.isUserInteractionEnabled = false
        portraitSeekSlider.maximumValue = Float(video.duration.duration())
        portraitSeekSlider.setThumbImage(UIImage.image("thumb"), for: .normal)
        portraitSeekSlider.tintColor = .clear//UIColor.color("a_pink")
        portraitSeekSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)
        portraitSeekSlider.setMaximumTrackImage(createMaxTrackImage(for: portraitSeekSlider), for: .normal)
      }
    }
  }
  
  @IBOutlet weak var landscapeSeekSlider: CustomSlide! {
    didSet {
      if let video = videoContent as? VOD {
        landscapeSeekSlider.setMaximumTrackImage(createMaxTrackImage(for: landscapeSeekSlider), for: .normal)
        landscapeSeekSlider.maximumValue = Float(video.duration.duration())
        landscapeSeekSlider.setThumbImage(UIImage.image("thumb"), for: .normal)
        landscapeSeekSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)
      }
    }
  }
  
  @IBOutlet weak var seekLabel: UILabel! 

  //MARK: - new poll banner staff
  @IBOutlet private var pollBannerAspectRatio: NSLayoutConstraint!
  @IBOutlet private var pollBannerPortraitLeading: NSLayoutConstraint!
  @IBOutlet private var pollTitleLabel: UILabel!
  @IBOutlet private var pollBannerView: UIView!
  @IBOutlet private var pollBannerIcon: UIImageView!
  var shouldShowExpandedBanner = true
  //MARK: -

  //MARK: - edit profile staff
  @IBOutlet private var editProfileContainerPortraitBottom: NSLayoutConstraint!
  @IBOutlet private var editProfileContainerLandscapeBottom: NSLayoutConstraint!
  private var pollAnswersFromLastView = 0
  private var shouldShowPollBadge = false
  private var isFirstTimeBannerShown = true
  //MARK: -

  //MARK: - player header staff
  @IBOutlet private var circleImageView: UIImageView! {
    didSet {
      userImageView.load(url: URL(string: videoContent.broadcasterPicUrl), placeholder: UIImage.image("avaPic"))
    }
  }
  @IBOutlet private var titleLabel: UILabel! {
    didSet {
      titleLabel.text = videoContent.title
    }
  }
  @IBOutlet private var subtitleLabel: UILabel! {
    didSet{
      subtitleLabel.text = String(format: "%@ • %@", videoContent.creatorNickname, videoContent.date.timeAgo())
      updateContentTimeAgo()
    }
  }
  @IBOutlet var landscapeCircleImageView: UIImageView! {
    didSet {
      landscapeUserImageView.load(url: URL(string: videoContent.broadcasterPicUrl), placeholder: UIImage.image("avaPic"))
    }
  }
  @IBOutlet var landscapeTitleLabel: UILabel! {
    didSet {
      landscapeTitleLabel.text = videoContent.title
    }
  }
  @IBOutlet var landscapeSubtitleLabel: UILabel! {
    didSet{
      landscapeSubtitleLabel.text = String(format: "%@ • %@", videoContent.creatorNickname, videoContent.date.timeAgo())
    }
  }
  @IBOutlet var liveToLandscapeInfoTop: NSLayoutConstraint!
  @IBOutlet var headerHeightConstraint: NSLayoutConstraint!
  
  lazy var userImageView: CacheImageView = {
    let imageView = CacheImageView()
    circleImageView.addSubview(imageView)
    fixImageView(imageView, in: circleImageView)
    return imageView
  }()

  lazy var landscapeUserImageView: CacheImageView = {
    let imageView = CacheImageView()
    landscapeCircleImageView.addSubview(imageView)
    fixImageView(imageView, in: landscapeCircleImageView)
    return imageView
  }()
  var timeAgoWorkItem: DispatchWorkItem?
  //MARK: -

  fileprivate var currentOrientation: UIInterfaceOrientation! {
    didSet {
      if currentOrientation != oldValue {
        if videoContent is VOD {
          seekTo = nil
        }
        adjustHeightForTextView(chatTextView)
        if OrientationUtility.isLandscape {
          let leftInset = view.safeAreaInsets.left
          if leftInset > 0 {
            var leading: CGFloat = .zero
            var trailing: CGFloat = .zero
            if chatTextView.isFirstResponder {
              trailing = OrientationUtility.currentOrientatin == .landscapeLeft ? 30 : 0
              leading = OrientationUtility.currentOrientatin == .landscapeLeft ? 0 : 30
            }
            bottomContainerTrailing.constant = trailing
            bottomContainerLeading.constant = leading
          }
          if isBottomContainerHidedByUser {
            chatTextView.resignFirstResponder()
          }
          if !viewersCountView.isHidden {
            liveToLandscapeInfoTop?.isActive = !isPlayerControlsHidden
            view.layoutIfNeeded()
          }
          if videoContent is Live {
            landscapeSeekSlider.removeFromSuperview()
          }
        } else {
          liveLabel.alpha = 1
          viewersCountView.alpha = 1
          bottomContainerLeading.constant = .zero
          bottomContainerTrailing.constant = .zero
        }
        if isAutoplayMode {
          adjustCircleLayersPath()
        }
        if shouldShowExpandedBanner, activePoll?.userAnswer == nil, activePoll != nil {
          expandPollBanner()
        }
        chatController.updateContentInsetForTableView()
        updateChatVisibility()
        updateBottomContainerVisibility()
        updatePollBannerVisibility()
      }
    }
  }

  fileprivate var isReachable: Bool {
    URLSessionNetworkDispatcher.instance.isReachable
  }

  private func updatePollBannerVisibility() {
    pollBannerView.isHidden = activePoll == nil
    if OrientationUtility.isLandscape {
      if !isPlayerControlsHidden {
        pollBannerView.alpha = 0
      } else {
        pollBannerView.alpha = activePoll == nil ? 0 : 1

      }
    } else {
      pollBannerView.alpha = activePoll == nil ? 0 : 1
    }
  }

  lazy var formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()
  fileprivate var pollManager: PollManager?
  fileprivate var isShouldShowPollAnswers = false
  fileprivate var pollBannerDebouncer = Debouncer(delay: 6)
  fileprivate var activePoll:  Poll? {
    didSet {
      NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "PollUpdated"), object: nil, userInfo: ["poll" : activePoll ?? 0])
      guard let poll = activePoll else {
        pollBannerDebouncer.call {}
        self.isShouldShowPollAnswers = false
        self.shouldShowExpandedBanner = true
        self.isFirstTimeBannerShown = true
        self.pollControllerCloseButtonPressed()
        self.collapsePollBanner()
        updatePollBannerVisibility()
        self.pollBannerIcon.hideBadge()
        return
      }

      poll.onUpdate = { [weak self] in
        guard let `self` = self, self.activePoll != nil else { return }
        if self.pollBannerView.isHidden {
          self.updatePollBannerVisibility()
          poll.userAnswer != nil ? self.collapsePollBanner(animated: false) : self.expandPollBanner()
          self.pollTitleLabel.text = poll.pollQuestion
        }

        NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "PollUpdated"), object: nil, userInfo: ["poll" : self.activePoll ?? 0])
        if self.activePoll?.userAnswer != nil, self.pollContainerView.isHidden, self.shouldShowPollBadge {
          let count = self.activePoll?.answersCount.reduce(0, +) ?? 0
          let dif = count - self.pollAnswersFromLastView - 1
          if dif > 0 {
            self.pollBannerIcon.addBadge(title: String(format: "%d", dif), belowView: self.pollContainerView)
          }
        }
      }
    }
  }

  fileprivate var isKeyboardShown = false
  
  private var chatGradientLayer: CAGradientLayer = {
    let gradient = CAGradientLayer()
    gradient.colors = [UIColor.clear.withAlphaComponent(0).cgColor, UIColor.clear.withAlphaComponent(0.7).cgColor, UIColor.clear.withAlphaComponent(1).cgColor, UIColor.clear.withAlphaComponent(1).cgColor]
    gradient.locations = [0, 0.15, 0.5, 1]
    return gradient
  }()
  
  private var isChatEnabled = false {
    didSet {
      sendButton.isEnabled = isChatEnabled
      chatTextView.isEditable = isChatEnabled

      chatTextView.placeholder = isChatEnabled ? LocalizedStrings.chat.localized :
        LocalizedStrings.chatDisabled.localized
      updateBottomContainerVisibility()
      let alpha: CGFloat = isChatEnabled ? 0.6 : 0.2
      chatTextViewHolderView.layer.borderColor = UIColor.white.withAlphaComponent(alpha).cgColor
      chatTextView.placeholderTextColor = isChatEnabled ? .cellGray : .bottomMessageGray
      view.layoutIfNeeded()
      if !isChatEnabled {
        chatTextView.text = ""
      }
    }
  }
  
  private var chat: Chat? {
    didSet {
      chat?.onAdd = { [weak self] message in
        self?.videoContent is VOD ? self?.chatController.vodMessages.append(message) : self?.chatController.insertMessages([message])
      }
      chat?.onRemove = { [weak self] message in
        self?.chatController.deleteMessages([message])
      }
      chat?.onStateChange = { [weak self] isActive in
        if self?.videoContent is Live {
          self?.isChatEnabled = isActive
          if self?.shouldEnableChatField == true, isActive {
            self?.chatTextView.becomeFirstResponder()
          }
          self?.shouldEnableChatField = false
        } else {
          self?.isChatEnabled = false
        }
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        self?.chatController.scrollToBottom()
      }
    }
  }
  
  var videoContent: VideoContent!
  fileprivate var isVideoEnd = false
  fileprivate var isPlayerError = false
  
  fileprivate var pollController: PollController?

  
  fileprivate var isControlsEnabled = false
  fileprivate var controlsDebouncer = Debouncer(delay: 1.2)
  fileprivate var controlsAppearingDebouncer = Debouncer(delay: 0.4)
  fileprivate var seekByTapDebouncer = Debouncer(delay: 0.7)
  
  //MARK: For vods
  fileprivate var vodMessages: [Message]? = []
  fileprivate var chatFieldLeading: CGFloat! {
    didSet {
      chatFieldLeadingChanged?(chatFieldLeading)
    }
  }
  var chatFieldLeadingChanged: ((CGFloat) -> ())?
  private var timeOfLastTap: Date?
  fileprivate var seekToByTapping: Int?
  fileprivate var isSeekByTappingMode = false
  fileprivate var seekPaddingView: SeekPaddingView?
  fileprivate var isPlayerControlsHidden: Bool = true {
    didSet {
      setPlayerControlsHidden(isPlayerControlsHidden)
    }
  }

  private lazy var bottomMessage = BottomMessage(presentingController: self)

  fileprivate var seekTo: Int? {
    didSet {
      if seekTo == nil, let time = oldValue {
        player.player.rate = 0
        self.isVideoEnd = false
        player.seek(to: CMTime(seconds: Double(time), preferredTimescale: 1), completionHandler: { [weak self] (value) in
          self?.player.isPlayerPaused ?? false ? self?.player.pause() : self?.player.play()
          
          if self?.isSeekByTappingMode ?? true {
            self?.isSeekByTappingMode = false
          }
          self?.shouldShowSkipButton = false
          self?.setSkipButtonHidden(hidden: true)
          
        })
        controlsDebouncer.call { [weak self] in
          if self?.player.isPlayerPaused == false {
            if OrientationUtility.isLandscape && self?.seekTo != nil {
              return
            }
            self?.isPlayerControlsHidden = true
          }
        }
      }
    }
  }
  var shouldEnableChatField = false
  
  override var preferredStatusBarStyle : UIStatusBarStyle {
    return .lightContent
  }
  
  override var prefersStatusBarHidden: Bool {
    let window = UIApplication.shared.keyWindow
    let bottomPadding = window?.safeAreaInsets.bottom
    return bottomPadding == 0
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    previousButton.isExclusiveTouch = true
    nextButton.isExclusiveTouch = true

    addChild(chatController)
    chatController.view.fixInView(chatContainerView)
    chatController.didMove(toParent: self)
    //FIXME:
    OrientationUtility.rotateToOrientation(OrientationUtility.currentOrientatin)
    currentOrientation = OrientationUtility.currentOrientatin
    self.dataSource.pauseUpdatingStreams()
     var token: NSObjectProtocol?
     token = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] (notification) in
       guard let `self` = self else {
         NotificationCenter.default.removeObserver(token!)
         return
       }
       self.currentOrientation = OrientationUtility.currentOrientatin
     }

      if self.videoContent is Live {

         self.pollManager = PollManager(streamId: self.videoContent.id)
         self.pollManager?.observePolls(completion: { [weak self] (poll) in
            self?.activePoll = poll
          })
         self.streamTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self] (myTimer) in
            guard let `self` = self else {
              myTimer.invalidate()
              return
            }
            self.dataSource.getViewers(for: self.videoContent.id) { (result) in
              switch result {
              case .success(let count):
                self.viewersCountLabel.text = count.formatUsingAbbrevation()
              case .failure(let error):
                print(error.localizedDescription)
              }
            }
          })

        }
    updateBottomContainerVisibility()
    
    DispatchQueue.main.async { [weak self] in
      guard let `self` = self else { return }
      self.isChatEnabled = false
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      Statistic.send(action: .open, for: self.videoContent)
      self.chat = Chat(for: self.videoContent)
      self.startPlayer()
    }
    self.adjustHeightForTextView(self.chatTextView)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    adjustVideoControlsButtons()
    NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundHandler), name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleWillBecomeActive(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    UIApplication.shared.isIdleTimerDisabled = true
    startObservingReachability()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    chatController.updateContentInsetForTableView()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    NotificationCenter.default.removeObserver(self)
    view.endEditing(true)
    UIApplication.shared.isIdleTimerDisabled = false
    if let vod = videoContent as? VOD {
      let seconds = player?.currentTime ?? 0
      vod.isNew = false
      vod.stopTime = min(Int(seconds.isNaN ? 0 : seconds), vod.duration.duration()).durationString()
    }
    dataSource.startUpdatingStreams()
    streamTimer?.invalidate()
    stopObservingReachability()
  }
  
  deinit {
    print("Player DEINITED")
    pollManager?.removeFirObserver()
    Statistic.send(action: .close(span: Int(activeSpendTime)), for: videoContent)
    SponsoredBanner.current = nil
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    if videoContent is VOD {
      updateBottomContainerVisibility()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if OrientationUtility.isLandscape {
      updateBottomContainerGradientFrame()
    }
    userImageView.layer.cornerRadius = userImageView.bounds.width/2
    landscapeUserImageView.layer.cornerRadius = landscapeUserImageView.bounds.width/2
  }

  func collapsePollBanner(animated: Bool = true) {
    pollBannerPortraitLeading.isActive = false
    pollBannerAspectRatio.isActive = true
    UIView.animate(withDuration: animated ? 0.3 : 0, animations: {
      self.view.layoutIfNeeded()
    })
  }

  func expandPollBanner() {

    pollBannerAspectRatio.isActive = false
    if OrientationUtility.currentOrientatin.isPortrait {
      pollBannerPortraitLeading.isActive = true
    }
    UIView.animate(withDuration: 0.3, animations: {
      self.view.layoutIfNeeded()
    })
    guard isFirstTimeBannerShown else { return }
    isFirstTimeBannerShown = false
    pollBannerDebouncer.call { [weak self] in
      self?.shouldShowExpandedBanner = false
      self?.collapsePollBanner()
    }
  }

  func collapseChatTextView() {
    chatTextViewHolderViewLeading.isActive = false
    editProfileButton.isHidden = false
    chatTextViewTrailing.isActive = chatTextView.text.isEmpty
    bottomContainerLeading.constant = .zero
    bottomContainerTrailing.constant = .zero
    UIView.animate(withDuration: 0.3) {
      self.view.layoutIfNeeded()
    }
  }

  func expandChatTextView() {
    chatTextViewHolderViewLeading.isActive = true
    chatTextViewTrailing.isActive = false
    editProfileButton.isHidden = true
    if view.safeAreaInsets.left > 0, OrientationUtility.isLandscape {
      let leading: CGFloat = OrientationUtility.currentOrientatin == .landscapeLeft ? 0 : 30
      let trailing: CGFloat = OrientationUtility.currentOrientatin == .landscapeLeft ? 30 : 0
      bottomContainerTrailing.constant = trailing
      bottomContainerLeading.constant = leading
    }
    UIView.animate(withDuration: 0.3) {
      self.view.layoutIfNeeded()
    }
  }

  private func updateChatVisibility() {
    if videoContent is Live {
      guard !isVideoEnd else {
        chatContainerView.alpha = currentOrientation.isLandscape ? 0 : 1//isHidden = currentOrientation.isLandscape
        return
      }
      if currentOrientation.isLandscape {
        let hidden = !isPlayerControlsHidden || !pollContainerView.isHidden
        chatContainerView.alpha = hidden ? 0 : 1//!videoControlsView.isHidden || !pollContainerView.isHidden
        return
      }
    } else {
      if currentOrientation.isLandscape {
        let hidden = !isPlayerControlsHidden || isAutoplayMode
        chatContainerView.alpha = hidden ? 0 : 1//!videoControlsView.isHidden || isAutoplayMode
        return
      }
    }
    chatContainerView.alpha = 1
  }

  private func updateBottomContainerVisibility(animated: Bool = false) {
    defer {
      UIView.animate(withDuration: animated ? 0.3 : 0) {
        self.view.layoutIfNeeded()
      }
    }
    if videoContent is Live {
      guard !isVideoEnd else {
        bottomContainerView.alpha = currentOrientation.isLandscape ? 0 : 1//isHidden = currentOrientation.isLandscape
        bottomContainerGradientLayer.removeFromSuperlayer()
        return
      }
      if currentOrientation.isLandscape {
        let hidden = !isPlayerControlsHidden || !pollContainerView.isHidden
        bottomContainerView.alpha = hidden ? 0 : 1//!videoControlsView.isHidden || !pollContainerView.isHidden
        bottomContainerLandscapeTop.isActive = isBottomContainerHidedByUser
        bottomContainerGradientLayer.removeFromSuperlayer()
        bottomContainerView.layer.insertSublayer(bottomContainerGradientLayer, at: 0)
        return
      }
      bottomContainerView.alpha = 1
      bottomContainerView.isHidden = false
      bottomContainerPortraitTop.isActive = false
    } else {
      bottomContainerView.alpha = 0
      bottomContainerPortraitTop.isActive = true
      bottomContainerLandscapeTop.isActive = true
    }
    bottomContainerGradientLayer.removeFromSuperlayer()
  }


  func updateContentTimeAgo() {
    guard videoContent.date <= Date() else {
      timeAgoWorkItem?.cancel()
      timeAgoWorkItem = nil
      return
    }
    let components = Calendar.current.dateComponents([.hour], from: videoContent.date, to: Date())
    timeAgoWorkItem?.cancel()
    timeAgoWorkItem = nil
    timeAgoWorkItem = DispatchWorkItem { [weak self] in
      guard let `self` = self else { return }
      let text = String(format: "%@ • %@", self.videoContent.creatorNickname, self.videoContent.date.timeAgo())
      self.subtitleLabel.text = text
      self.landscapeSubtitleLabel.text = text
      self.updateContentTimeAgo()
    }
    if let hours = components.hour,
      let workItem = timeAgoWorkItem {
      let delay: Double = hours > 0 ? 3600 : 60
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
  }

  private func fixImageView(_ imageView: CacheImageView, in parentView: UIView) {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.centerXAnchor.constraint(equalToSystemSpacingAfter: parentView.centerXAnchor, multiplier: 1).isActive = true
    imageView.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
    imageView.widthAnchor.constraint(equalTo: parentView.widthAnchor, multiplier: 0.8).isActive = true
    imageView.heightAnchor.constraint(equalTo: parentView.heightAnchor, multiplier: 0.8).isActive = true
    imageView.layer.masksToBounds = true
  }

  private func createMaxTrackImage(for slider: CustomSlide) -> UIImage {
    let backgroundColor = UIColor.white.withAlphaComponent(0.6)
    let width: CGFloat = 1200
    let imageSize = CGSize(width: width, height: slider.trackHeight)
    UIGraphicsBeginImageContext(imageSize)
    backgroundColor.setFill()
    UIRectFill(CGRect(origin: .zero, size: imageSize))
    guard let content = videoContent as? VOD  else {
      let newImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      return newImage ?? UIImage()
    }
    for curtain in content.curtainRangeModels {
      var cur = curtain
      let lowerBoudn = cur.range.lowerBound
      let upperBoudn = cur.range.upperBound
      let videoDuration = Double(content.duration.duration())
      let context = UIGraphicsGetCurrentContext()!
      let origin = CGPoint(x: CGFloat(lowerBoudn/videoDuration)*width, y: 0)
      let size = CGSize(width: CGFloat(upperBoudn/videoDuration)*width - origin.x, height: imageSize.height)
      UIColor.curtainYellow.setFill()
      context.fill(CGRect(origin: origin, size: size))
    }
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage ?? UIImage()
  }

  func startObservingReachability() {
    if !isReachable {
      let color = UIColor.color("a_bottomMessageGray")
      bottomMessage.showMessage(title: LocalizedStrings.noConnection.localized.uppercased() , backgroundColor: color ?? .gray)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(handleReachability(_:)), name: .reachabilityChanged, object: nil)
  }

  func stopObservingReachability() {
    NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: nil)
    bottomMessage.hideMessage()
  }

  @objc
  private func handleReachability(_ notification: Notification) {
    if isReachable {
      let color = UIColor.color("a_bottomMessageGreen")
      bottomMessage.showMessage(title: LocalizedStrings.youAreOnline.localized.uppercased(), duration: 2, backgroundColor: color ?? .green)
    } else {
      let color = UIColor.color("a_bottomMessageGray")
      bottomMessage.showMessage(title: LocalizedStrings.noConnection.localized.uppercased(), backgroundColor: color ?? .gray)
    }
  }

  @objc
  private func handleWillBecomeActive(_ notification: NSNotification) {
    if videoContent is Live {
      landscapeSeekSlider.removeFromSuperview()
    } else {
      portraitSeekSlider.setMaximumTrackImage(createMaxTrackImage(for: portraitSeekSlider), for: .normal)
      landscapeSeekSlider.setMaximumTrackImage(createMaxTrackImage(for: landscapeSeekSlider), for: .normal)
    }
    updateBottomContainerVisibility()
    if OrientationUtility.isLandscape {
      self.liveToLandscapeInfoTop?.isActive = !isPlayerControlsHidden
    }
    self.view.layoutIfNeeded()
  }
  
  private func startPlayer(){
    var seekTo: Double?
    if let vod = videoContent as? VOD {
      let alreadyWatchedTime = Double(vod.stopTime.duration())
      let duration = Double(vod.duration.duration())
      seekTo = alreadyWatchedTime/duration >= 0.9 ? 0 : alreadyWatchedTime
      var startCurtain = vod.curtainRangeModels.first { curtain in
        var tempCurt = curtain
        return tempCurt.range.lowerBound == 0 &&     
          tempCurt.range.contains(seekTo ?? 0)
        }
      currentCurtain = startCurtain
      if let curtainUpperBound = startCurtain?.range.upperBound {
        seekTo = Int(curtainUpperBound) >= vod.duration.duration() ? seekTo : curtainUpperBound
      }
    }

    guard let url = URL(string: videoContent.url) else {
      showError(autohide: false)
      return
    }

    player = Player(url: url, seekTo: seekTo)
    
    player.addPeriodicTimeObserver { [weak self] (time, isLikelyToKeepUp) in
      guard let `self` = self else {return}
      if isLikelyToKeepUp {
        self.videoContainerView.removeActivityIndicator()
        self.playButton.isHidden = false
        if !self.videoControlsView.isHidden {
          self.updatePlayButtonImage()
        }
      } else if self.player.isPlayerPaused == false, !self.videoContainerView.isActivityIndicatorLoaded {
        self.videoContainerView.showActivityIndicator()
        self.playButton.isHidden = true
      }
      self.activeSpendTime += 0.2
      
      if let vod = self.videoContent as? VOD {
        vod.stopTime = min(Int(time.seconds), vod.duration.duration()).durationString()
        self.chatController.handleVODsChat(forTime: Int(time.seconds))
        self.checkCurtains()
        //temp: needs refactoring
        self.seekLabel.text = String(format: "%@ / %@", Int(time.seconds).durationString(), vod.duration.duration().durationString())
        if self.seekTo == nil, self.player.player.rate == 1 {
          self.portraitSeekSlider.setValue(Float(time.seconds), animated: false)
          self.landscapeSeekSlider.setValue(Float(time.seconds), animated: false)
        }
      } else {
        self.seekLabel.text = String(format: "%@", Int(time.seconds).durationString())
      }
    }
    
    player.playerReadyToPlay = { [weak self] in
      self?.isControlsEnabled = true
      self?.videoContainerView.image = nil
    }
    
    //TODO: AirPlay
    
    videoContainerView.player = player.player
    
    player.onErrorApear = { [weak self] error in
      self?.playButton.setImage(UIImage.image("Play"), for: .normal)
      self?.isPlayerControlsHidden = false
      self?.videoContainerView.removeActivityIndicator()
      self?.isControlsEnabled = true
      if self?.isReachable == true {
        self?.showError()
      }
      self?.isPlayerError = true
    }
    
    player.onVideoEnd = { [weak self] in
      self?.playButton.setImage(UIImage.image("Play"), for: .normal)
      self?.isVideoEnd = true
      if self?.videoContent is VOD {
        self?.isSeekByTappingMode = false
        self?.seekByTapDebouncer.call {}
        self?.seekPaddingView = nil
        self?.isPlayerControlsHidden = false
        self?.startAutoplayNexItem()
      } else {
        //MARK: set thanks image
        self?.setThanksImage()
        self?.isChatEnabled = false
        self?.editProfileButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        self?.editProfileButton.tintColor = UIColor.white.withAlphaComponent(0.2)
        self?.videoContainerView.layer.sublayers?.first?.isHidden = true
        self?.liveLabelWidth.constant = 0
        self?.playButton.isHidden = true
        self?.view.layoutIfNeeded()
      }
      self?.updateChatVisibility()
      
    }
    videoContainerView.showActivityIndicator()
  }

  private func showError(autohide: Bool = true) {
    let color = UIColor.color("a_bottomMessageGray") ?? .gray
    let text = LocalizedStrings.generalError.localized.uppercased()
    bottomMessage.showMessage(title: text, duration: autohide ? 3 : .infinity, backgroundColor: color)
  }

  private func setThanksImage() {
    let text = LocalizedStrings.thanksForWatching.localized.uppercased()
    if let imageUrl = URL(string: videoContent.thumbnailUrl) {
      let _ =  ImageService.getImage(withURL: imageUrl) { [weak self] thumbnail in
        guard let `self` = self, let thumbnail = thumbnail else { return }
        let scale = UIScreen.main.scale
        let labelFrame = CGRect(origin: .zero, size: CGSize(width: thumbnail.size.width*3, height: thumbnail.size.height*3))
        UIGraphicsBeginImageContextWithOptions(labelFrame.size, false, scale)
        thumbnail.draw(in: labelFrame)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.withAlphaComponent(0.65).cgColor)
        context.fill(labelFrame)
        let label = UILabel(frame: labelFrame)
        label.text = text.uppercased()
        label.font = UIFont.systemFont(ofSize: labelFrame.size.height*0.06, weight: .bold)
        label.textAlignment = .center
        label.textColor = .white
        label.draw(labelFrame)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        self.isPlayerControlsHidden = true
        self.liveDurationLabel.text = self.seekLabel.text
        self.liveDurationLabel.isHidden = false
        self.videoContainerView.image = newImage
        self.videoContainerView.isUserInteractionEnabled = true
      }
    }
  }

  private func startAutoplayNexItem() {
    if nextButton.isHidden {
      playButton.setImage(UIImage.image("PlayAgain"), for: .normal)
      return
    }

    playButton.setImage(UIImage.image("PlayNext"), for: .normal)
    previousButton.isHidden = true
    nextButton.isHidden = true
    isAutoplayMode = true
    cancelButton.isHidden = false

    playButton.layer.addSublayer(backgroundShape)
    playButton.layer.addSublayer(progressShape)
    adjustCircleLayersPath()
    let strokeWidth: CGFloat = 2.64
    backgroundShape.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor
    backgroundShape.lineWidth = strokeWidth
    backgroundShape.fillColor = UIColor.clear.cgColor

    progressShape.strokeColor = UIColor.white.withAlphaComponent(0.67).cgColor
    progressShape.lineWidth = backgroundShape.lineWidth
    progressShape.fillColor = UIColor.clear.cgColor
    progressShape.lineCap = .round
    progressShape.strokeEnd = 0

    progressShape.removeAnimation(forKey: "fillAnimation")
    let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")
    basicAnimation.toValue = 1
    basicAnimation.duration = 5
    basicAnimation.fillMode = .forwards
    basicAnimation.isRemovedOnCompletion = false
    progressShape.add(basicAnimation, forKey: "fillAnimation")

    autoplayDebouncer.call { [weak self] in
      guard let `self` = self else { return }
      self.goToButtonPressed(self.nextButton)
    }
  }

  private func adjustCircleLayersPath() {
    // temp solution (doesn't work in viewDidLayoutSubviews)
    let side = OrientationUtility.isLandscape ? 84 : 56
    let size = CGSize(width: side, height: side)
    let frame = CGRect(origin: .zero, size: size)
    backgroundShape.frame = frame
    progressShape.frame = frame
    backgroundShape.path = UIBezierPath(ovalIn: playButton.bounds).cgPath
    progressShape.path = UIBezierPath(arcCenter: CGPoint(x: playButton.bounds.width/2, y: playButton.bounds.height/2), radius: playButton.bounds.width/2, startAngle: -CGFloat.pi/2, endAngle: 1.5 * CGFloat.pi, clockwise: true).cgPath
  }


  @IBAction func cancelButtonTapped(_ sender: UIButton?) {
    autoplayDebouncer.call {}
    isAutoplayMode = false
    previousButton.isHidden = false
    nextButton.isHidden = false
    adjustVideoControlsButtons()
    updatePlayButtonImage()
    backgroundShape.removeFromSuperlayer()
    progressShape.removeFromSuperlayer()
    cancelButton.isHidden = true
  }

  @IBAction func skipCurtainButtonTapped(_ sender: UIButton) {
    //MARK: skip curtain
    defer {
      skipCurtainButtonDebouncer.call { }
      setSkipButtonHidden(hidden: true)
    }
    guard let vod = videoContent as? VOD,
      var currentCurtain = vod.curtainRangeModels
        .first(where: {
        var curtain = $0
        return curtain.range.contains(player.currentTime)
      }) else {
        return
    }
    seekTo = Int(currentCurtain.range.upperBound)
    seekTo = nil
  }

  private func checkCurtains() {
    guard let vod = videoContent as? VOD,
    var curtain = vod.curtainRangeModels
      .first(where: {
      var curtain = $0
      return curtain.range.contains(player.currentTime)
      }) else {
        currentCurtain = nil
        setSkipButtonHidden(hidden: true)
        shouldShowSkipButton = true
        return
    }

    if var currentCurtain = currentCurtain {
      if currentCurtain.range != curtain.range {
        currentCurtain = curtain
        shouldShowSkipButton = false
        setSkipButtonHidden(hidden: true)
      }
    } else if Int(curtain.range.upperBound) >= vod.duration.duration() {
      currentCurtain = curtain
      shouldShowSkipButton = false
      setSkipButtonHidden(hidden: true)
    } else {
      currentCurtain = curtain
      setSkipButtonHidden(hidden: !shouldShowSkipButton)
      skipCurtainButtonDebouncer.call { [weak self] in
      self?.shouldShowSkipButton = false
        self?.setSkipButtonHidden(hidden: true)
      }
    }
  }

  private func setSkipButtonHidden(hidden: Bool) {
    guard skipCurtainButton.isHidden != hidden else { return }
    if !hidden {
      skipCurtainButton.alpha = 0
      skipCurtainButton.isHidden = false
    }
    UIView.animate(withDuration: 0.2, animations: {
      self.skipCurtainButton.alpha = hidden ? 0 : 1
    }) { _ in
      if hidden {
        self.skipCurtainButton.isHidden = true
      }
    }
  }

  @objc
  private func onSliderValChanged(slider: UISlider, event: UIEvent) {
    if let touchEvent = event.allTouches?.first {
      switch touchEvent.phase {
      case .began:
        seekTo = Int(slider.value)
        isVideoEnd = false
        cancelButtonTapped(cancelButton)
      case .moved:
        seekTo = Int(slider.value)
      default:
        seekTo = nil
      }
    }
  }

  private func updateBottomContainerGradientFrame() {
    let topExtra: CGFloat = 35
    let origin = CGPoint(x: bottomContainerView.bounds.origin.x, y: -topExtra)
    let size = CGSize(width: bottomContainerView.bounds.width, height: bottomContainerView.bounds.height+topExtra+view.safeAreaInsets.bottom)
    bottomContainerGradientLayer.frame = CGRect(origin: origin, size: size)
  }

  private func adjustVideoControlsButtons() {
    guard videoContent is VOD else {
      nextButton.isHidden = true
      previousButton.isHidden = true
      return
    }
    let index = dataSource.videos.firstIndex(where: { $0.id == videoContent.id }) ?? 0
    let videosCount = dataSource.videos.count
    
    switch index {
    case 0:
      previousButton?.isHidden = true
    case videosCount - 2:
      if videosCount % 15 == 0 {
        dataSource.fetchNextItemsFrom(index: videosCount) { (_) in }
      }
    case videosCount - 1:
      nextButton?.isHidden = true
    default:
      break
    }
  }

  @IBAction func fullScreenButtonPressed(_ sender: UIButton?) {
    OrientationUtility.rotateToOrientation(OrientationUtility.isPortrait ? .landscapeRight : .portrait)
  }
  
  @IBAction func closeButtonPressed(_ sender: UIButton?) {
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    player?.stop()
    dismiss(animated: true, completion: nil)
  }
  
  @objc
  private func didEnterBackgroundHandler() {
    player?.pause()
    updatePlayButtonImage()
    if !liveDurationLabel.isHidden, videoContent is Live {
      isPlayerControlsHidden = true
    }
    if isAutoplayMode {
      cancelButtonTapped(nil)
    }
    chatTextView.resignFirstResponder()
  }
  
  func handleSeekByTapping(_ backwardDirection: Bool) {
    guard let vod = self.videoContent as? VOD else { return }
    self.controlsAppearingDebouncer.call {}
    self.isPlayerControlsHidden = true
    if OrientationUtility.isLandscape {
      self.liveToLandscapeInfoTop?.isActive = false
      self.view.layoutIfNeeded()
    }
    let activeSlider = OrientationUtility.currentOrientatin == .portrait ? self.portraitSeekSlider : self.landscapeSeekSlider
    self.seekTo = Int(activeSlider?.value ?? 0)
    
    if self.seekToByTapping == nil {
      self.seekToByTapping = self.seekTo
    }
    
    self.seekToByTapping! += backwardDirection ? -10 : 10
    
    switch self.seekToByTapping! {
    case let val where val < 0:
      self.seekToByTapping = 0
    case let val:
      self.seekToByTapping = (vod.duration.duration() >= val) ? val : (vod.duration.duration() - 1)
    }
    //Initialization of seekPaddingView
    if self.seekPaddingView == nil {
      self.seekPaddingView = SeekPaddingView(showInView: self.videoContainerView)
    }
    //seek forward/backward
    if backwardDirection {
      self.seekPaddingView?.seekBackward()
      self.seekPaddingView?.soughtTime = self.seekToByTapping! == 0 ? 10 : (self.seekPaddingView?.soughtTime)! + 10
    } else {
      self.seekPaddingView?.seekForward()
      self.seekPaddingView?.soughtTime = (self.seekToByTapping! != vod.duration.duration() - 1) ? (self.seekPaddingView?.soughtTime)! + 10 : 10
    }
    activeSlider?.setValue(Float(self.seekToByTapping!), animated: true)
    self.seekTo = self.seekToByTapping
    
    seekByTapDebouncer.call { [weak self] in
      self?.seekToByTapping = nil
      self?.timeOfLastTap = nil
      self?.seekTo = nil
      self?.updatePlayButtonImage()
      self?.seekPaddingView = nil
    }
  }
  
  @IBAction func handleTouchOnVideo(_ sender: UITapGestureRecognizer) {
    onVideoTapped(sender)
  }

  private func onVideoTapped(_ tapGesture: UITapGestureRecognizer? = nil, shouldCheckLocation: Bool = true) {
    guard !isAutoplayMode else { return }
    var onButtons = false
    var isLeftSide = true
    if shouldCheckLocation, let geture = tapGesture {
      let views: [UIView] = [cancelButton, playButton, skipCurtainButton] + fullScreenButtons
      onButtons = views.map { $0.frame.contains(geture.location(in: videoContainerView)) && !isPlayerControlsHidden }.reduce(false) { $0 || $1 }
      isLeftSide = geture.location(in: self.videoContainerView).x < self.videoContainerView.bounds.width / 2
    }

    guard isControlsEnabled else { return }
    if isKeyboardShown {
      chatTextView.endEditing(true)
      return
    }

    guard !onButtons, !(!pollContainerView.isHidden&&OrientationUtility.isLandscape) else { return }
    //MARK: seek by typing
    self.updatePlayButtonImage()
    if self.isSeekByTappingMode, videoContent is VOD {
      self.isPlayerControlsHidden = true
      handleSeekByTapping(isLeftSide)
    } else {
      if self.timeOfLastTap == nil {
        self.timeOfLastTap = Date()
      } else {
        if Date().timeIntervalSince(self.timeOfLastTap!) > 0.3 {
          self.timeOfLastTap = nil
          self.seekToByTapping = nil
          self.isSeekByTappingMode = false
        } else {
          self.isSeekByTappingMode = true
          handleSeekByTapping(isLeftSide)
        }
      }
    }
    guard !self.isSeekByTappingMode else { return }
    self.isPlayerControlsHidden = !self.isPlayerControlsHidden
  }
  
  @objc
  func handleHideKeyboardGesture(_ sender: UITapGestureRecognizer) {
    if isKeyboardShown {
      chatTextView.endEditing(true)
    }
  }
  
  func setPlayerControlsHidden(_ isHidden: Bool) {
    if !isHidden {
      self.controlsDebouncer.call { }
    }
    controlsAppearingDebouncer.call { [weak self] in
      guard let `self` = self else { return }
      self.startLabel.text = self.videoContent.date.timeAgo()

      if !isHidden {
        self.videoControlsView.alpha = 0
        self.videoControlsView.isHidden = false
      }
      UIView.animate(withDuration: 0.2, animations: {
        self.videoControlsView.alpha = isHidden ? 0 : 1
        self.updateSeekThumbAppearance(isHidden: isHidden)
        self.skipCurtainButton.alpha = !isHidden ? 0 : 1
        if OrientationUtility.isLandscape {
          self.liveToLandscapeInfoTop?.isActive = !isHidden
          self.view.layoutIfNeeded()
          self.updatePollBannerVisibility()
        }
        self.updateChatVisibility()
        self.updateBottomContainerVisibility()
      }) { (finished) in
        if isHidden {
          self.videoControlsView.isHidden = true
        }
      }
      guard !self.isPlayerControlsHidden else { return }
      self.controlsDebouncer.call { [weak self] in
        guard let `self` = self else { return }
        if !self.player.isPlayerPaused || !(self.isVideoEnd && self.isAutoplayMode) {
          if OrientationUtility.isLandscape && self.seekTo != nil {
            return
          }
          self.isPlayerControlsHidden = true
        }
      }
    }
  }
  
  func updateSeekThumbAppearance(isHidden: Bool) {
    let thumbTintColor = isHidden ? .clear : UIColor.color("a_pink")
    self.portraitSeekSlider.tintColor = thumbTintColor
    self.portraitSeekSlider.isUserInteractionEnabled = !isHidden
    self.landscapeSeekSlider?.tintColor = thumbTintColor
    self.landscapeSeekSlider?.isUserInteractionEnabled = !isHidden
  }
  
  @IBAction func playButtonPressed(_ sender: UIButton) {
    if self.isVideoEnd {
      if isAutoplayMode {
        goToButtonPressed(nextButton)
        return
      }
      self.isVideoEnd = false
      self.player.seek(to: .zero)
    }
    
    if player.isPlayerPaused {
      if isPlayerError {
        player.reconnect()
      } else {
        player.play()
      }
      
      controlsDebouncer.call { [weak self] in
        self?.isPlayerControlsHidden = true
      }
      
    } else {
      player.pause()
      controlsDebouncer.call {}
    }
    updatePlayButtonImage()
  }
  
  func updatePlayButtonImage() {
    guard !isAutoplayMode else { return }
    let image = (player?.isPlayerPaused == false) ? UIImage.image("Pause") :
      isVideoEnd ? UIImage.image("PlayAgain") : UIImage.image("Play")
    self.playButton.setImage(image, for: .normal)
  }
  
  @IBAction func sendButtonPressed(_ sender: UIButton) {
    guard let user = User.current else {
      return
    }
    guard let text = chatTextView.text, text.trimmingCharacters(in: .whitespacesAndNewlines).count != 0 else {
      chatTextView.text.removeAll()
      self.adjustHeightForTextView(self.chatTextView)
      return
    }
    guard let _ = videoContent as? AntViewerExt.Live else {return}
    sender.isEnabled = false
    let message = Message(userID: "\(user.id)", nickname: user.displayName, text: text, avatarUrl: User.current?.imageUrl)
    chatTextView.text.removeAll()
    if !chatTextView.isFirstResponder {
      collapseChatTextView()
    }
    self.adjustHeightForTextView(self.chatTextView)
    sender.isEnabled = !isReachable
    self.chat?.send(message: message) { (error) in
      if error == nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
          self.chatController.scrollToBottom()
        })
      }
      sender.isEnabled = true
    }
  }
  
  func shouldEnableMessageTextFields(_ enable: Bool) {
    self.chatTextView.isEditable = enable && isChatEnabled
    self.sendButton.isEnabled = enable && isChatEnabled
  }
  
  @IBAction func editProfileButtonPressed(_ sender: UIButton?) {
    if editProfileContainerView.isHidden {
      showEditProfileView()
    } else {
      dismissEditProfileView()
    }
  }
  
  var editProfileControllerIsLoading = false
  
  func showEditProfileView() {
    guard pollContainerView.isHidden else { return }
    editProfileControllerIsLoading = true
    shouldEnableMessageTextFields(false)
    let editProfileController = EditProfileViewController(nibName: "EditProfileViewController", bundle: Bundle(for: type(of: self)))
    editProfileController.delegate = self
    addChild(editProfileController)
    editProfileContainerView.addSubview(editProfileController.view)
    editProfileController.didMove(toParent: self)
    editProfileController.view.translatesAutoresizingMaskIntoConstraints = false
    UIView.performWithoutAnimation {
      editProfileController.view.topAnchor.constraint(equalTo: self.editProfileContainerView.topAnchor).isActive = true
      editProfileController.view.leftAnchor.constraint(equalTo: self.editProfileContainerView.leftAnchor).isActive = true
      editProfileController.view.rightAnchor.constraint(equalTo: self.editProfileContainerView.rightAnchor).isActive = true
      editProfileController.view.bottomAnchor.constraint(equalTo: self.editProfileContainerView.bottomAnchor).isActive = true
    }

    let paddingView = UIView(frame: view.bounds)
    paddingView.backgroundColor = UIColor.gradientDark.withAlphaComponent(0.8)
    paddingView.tag = 1234
    paddingView.translatesAutoresizingMaskIntoConstraints = false
    view.insertSubview(paddingView, belowSubview: editProfileContainerView)
    paddingView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    paddingView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    paddingView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    paddingView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    editProfileContainerView.isHidden = false
  }
  
  func dismissEditProfileView() {
    shouldEnableMessageTextFields(true)
    view.subviews.first { $0.tag == 1234 }?.removeFromSuperview()
    editProfileContainerView.isHidden = true
    let editProfile = children.first(where: { $0 is EditProfileViewController})
    editProfile?.willMove(toParent: nil)
    editProfile?.view.removeFromSuperview()
    editProfile?.removeFromParent()
  }
  
  fileprivate func adjustHeightForTextView(_ textView: UITextView) {
    let fixedWidth = textView.frame.size.width
    let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
    messageHeight.constant = newSize.height > 26 ? newSize.height : 26
    view.layoutIfNeeded()
  }
  
  @IBAction func handleSwipeGesture(_ sender: UISwipeGestureRecognizer) {
    let halfOfViewWidth = view.bounds.width / 2
    guard OrientationUtility.isLandscape, sender.location(in: view).x <= halfOfViewWidth else {return}
    handleSwipe(isRightDirection: true)
  }

  private func handleSwipe(isRightDirection: Bool) {
    guard editProfileContainerView.isHidden, videoControlsView.isHidden else { return }
    if videoContent is Live {
      isBottomContainerHidedByUser = !isRightDirection
    }
    updateBottomContainerVisibility(animated: true)
    chatContainerViewLandscapeLeading.constant = isRightDirection ? 16 : chatContainerView.bounds.width+16
    view.endEditing(false)
    UIView.animate(withDuration: 0.3) {
      self.view.layoutIfNeeded()
      self.chatController.updateContentInsetForTableView()
    }
  }

  @IBAction func handleHideGesture(_ sender: UISwipeGestureRecognizer) {
    if currentOrientation.isPortrait {
      closeButtonPressed(nil)
    } else {
      fullScreenButtonPressed(nil)
    }
  }

  @IBAction func openPollBannerPressed(_ sender: Any) {
    guard editProfileContainerView.isHidden else { return }
    dismissEditProfileView()
    shouldEnableMessageTextFields(false)
    view.endEditing(true)
    pollController = PollController()
    pollController?.poll = activePoll
    guard let pollController = pollController else {return}
    addChild(pollController)
    pollContainerView.addSubview(pollController.view)
    pollController.view.frame = pollContainerView.bounds
    pollController.didMove(toParent: self)
    pollController.delegate = self
    pollContainerView.isHidden = false
    updateChatVisibility()
    pollBannerIcon.hideBadge()
    collapsePollBanner(animated: false)
    shouldShowPollBadge = true
    shouldShowExpandedBanner = false
    updateBottomContainerVisibility()
  }

  
  @IBAction func goToButtonPressed(_ sender: UIButton) {
    let index = sender == nextButton ? 1 : -1
    
    guard let currentIndex = dataSource.videos.firstIndex(where: {$0.id == videoContent.id}), dataSource.videos.indices.contains(currentIndex + index),
      let navController = navigationController as? PlayerNavigationController else {
        return
    }
    let nextContent = dataSource.videos[currentIndex + index]
    let playerVC = PlayerController(nibName: "PlayerController", bundle: Bundle(for: type(of: self)))
    playerVC.videoContent = nextContent
    playerVC.dataSource = dataSource
    player.stop()
    navController.pushViewController(playerVC, withPopAnimation: sender == previousButton)
    
  }
}

//MARK: Keyboard handling
extension PlayerController {
  
  @objc
  fileprivate func keyboardWillChangeFrame(notification: NSNotification) {
    if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      let isHidden = keyboardSize.origin.y == view.bounds.height
      isKeyboardShown = !isHidden
      let userInfo = notification.userInfo!
      let animationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
      let rawAnimationCurve = (notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber).uint32Value << 16
      let animationCurve = UIView.AnimationOptions.init(rawValue: UInt(rawAnimationCurve))
      let bottomPadding = view.safeAreaInsets.bottom
      print(keyboardSize)
      if keyboardSize.width == view.frame.width {
        if isHidden {
          if editProfileControllerIsLoading { return }
          portraitMessageBottomSpace.constant = 0
          landscapeMessageBottomSpace.constant = 0
          liveLabel.alpha = 1
          viewersCountView.alpha = 1
          headerHeightConstraint.isActive = false
        } else if OrientationUtility.isLandscape {
          let isLeftInset = view.safeAreaInsets.left > 0
          chatFieldLeading = OrientationUtility.currentOrientatin == .landscapeRight && isLeftInset ? 30 : 0
          editProfileContainerLandscapeBottom.constant = keyboardSize.height
          landscapeMessageBottomSpace.constant = keyboardSize.height - bottomPadding
          liveLabel.alpha = 0
          viewersCountView.alpha = 0
        } else {
          if chatTextView.isFirstResponder {
            headerHeightConstraint.isActive = true
          }
          portraitMessageBottomSpace.constant = keyboardSize.height - bottomPadding
          editProfileContainerPortraitBottom.constant = keyboardSize.height
        }
      }
      adjustViewsFor(keyboardFrame: keyboardSize, with: animationDuration, animationCurve: animationCurve)
    }
  }

  
  func adjustViewsFor(keyboardFrame: CGRect, with animationDuration: TimeInterval, animationCurve: UIView.AnimationOptions) {
    adjustHeightForTextView(chatTextView)
    UIView.animate(withDuration: animationDuration, delay: 0, options: [.beginFromCurrentState, animationCurve], animations: {
      self.view.layoutIfNeeded()
      self.chatController.updateContentInsetForTableView()
    }, completion: nil)
  }
}

extension PlayerController: UITextViewDelegate {
  
  func textViewDidChange(_ textView: UITextView) {
    adjustHeightForTextView(textView)
  }
  
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    let curentText = text != "" ? (textView.text ?? "") + String(text.dropFirst()) : String((textView.text ?? " ").dropLast())
    
    if curentText.count > maxTextLength {
      textView.text = String(curentText.prefix(maxTextLength))
      return false
    }
    return textView.text.count + text.count - range.length <= maxTextLength
  }

  func textViewDidBeginEditing(_ textView: UITextView) {
    chatController.scrollToBottom()
  }

  func textViewDidEndEditing(_ textView: UITextView) {
    collapseChatTextView()
  }

  func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    
    if User.current?.displayName.isEmpty == true {
      if editProfileContainerView.isHidden, !editProfileControllerIsLoading {
        showEditProfileView()
      }
      return false
    }
    expandChatTextView()
    return true
  }
  
}


extension PlayerController: PollControllerDelegate {
  
  func pollControllerCloseButtonPressed() {
    pollController?.willMove(toParent: nil)
    pollController?.view.removeFromSuperview()
    pollController?.removeFromParent()
    pollController = nil
    pollContainerView.isHidden = true
    updateChatVisibility()
    pollAnswersFromLastView = activePoll?.answersCount.reduce(0,+) ?? 0
    updateBottomContainerVisibility()
    shouldEnableMessageTextFields(true)
  }
}


extension PlayerController: EditProfileControllerDelegate {
  func editProfileLoaded() {
    editProfileControllerIsLoading = false
  }
  
  func editProfileCloseButtonPressed(withChanges: Bool) {
    if withChanges {
      chatController.reloadData()
    }
    dismissEditProfileView()
  }
}

extension PlayerController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}
