//
//  YPLibraryView.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 2015/11/14.
//  Copyright © 2015 Yummypets. All rights reserved.
//

import AVKit
import MobileCoreServices
import UIKit
import Stevia
import Photos

internal final class YPLibraryView: UIView {

    // MARK: - Public vars

    internal let assetZoomableViewMinimalVisibleHeight: CGFloat  = 50
    internal var assetViewContainerConstraintTop: NSLayoutConstraint?
    internal let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let v = UICollectionView(frame: .zero, collectionViewLayout: layout)
        v.backgroundColor = YPConfig.colors.libraryScreenBackgroundColor
        v.collectionViewLayout = layout
        v.showsHorizontalScrollIndicator = false
        v.alwaysBounceVertical = true
        return v
    }()
    internal lazy var assetViewContainer: YPAssetViewContainer = {
        let v = YPAssetViewContainer(frame: .zero, zoomableView: assetZoomableView)
        v.accessibilityIdentifier = "assetViewContainer"
        return v
    }()
    internal let assetZoomableView: YPAssetZoomableView = {
        let v = YPAssetZoomableView(frame: .zero)
        v.accessibilityIdentifier = "assetZoomableView"
        return v
    }()
    /// At the bottom there is a view that is visible when selected a limit of items with multiple selection
    internal let maxNumberWarningView: UIView = {
        let v = UIView()
        v.backgroundColor = .ypSecondarySystemBackground
        v.isHidden = true
        return v
    }()
    internal let maxNumberWarningLabel: UILabel = {
        let v = UILabel()
        v.font = YPConfig.fonts.libaryWarningFont
        return v
    }()
    internal lazy var cameraImageView: UIImageView = {
        let v = UIImageView()
        v.image = YPConfig.icons.cameraButtonImage
        v.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cameraButtonTapped))
        v.addGestureRecognizer(tapGesture)
        return v
    }()
    internal lazy var galleryImageView: UIImageView = {
        let v = UIImageView()
        v.image = YPConfig.icons.galleryButtonImage
        v.isUserInteractionEnabled = true
        return v
    }()
    
    internal lazy var galleryCameraView: UIView = {
        let v = UIView()
        v.subviews(cameraImageView, galleryImageView)
        galleryImageView.width(35).height(35).right(16).top(8).bottom(8)
        cameraImageView.width(35).height(35).top(8).bottom(8)
        cameraImageView.Right == galleryImageView.Left - 8
        return v
    }()

    // MARK: - Private vars

    private let line: UIView = {
        let v = UIView()
        v.backgroundColor = .ypSystemBackground
        return v
    }()
    /// When video is processing this bar appears
    private let progressView: UIProgressView = {
        let v = UIProgressView()
        v.progressViewStyle = .bar
        v.trackTintColor = YPConfig.colors.progressBarTrackColor
        v.progressTintColor = YPConfig.colors.progressBarCompletedColor ?? YPConfig.colors.tintColor
        v.isHidden = true
        v.isUserInteractionEnabled = false
        return v
    }()
    private let collectionContainerView: UIView = {
        let v = UIView()
        v.accessibilityIdentifier = "collectionContainerView"
        return v
    }()
    private var shouldShowLoader = false {
        didSet {
            DispatchQueue.main.async {
                self.assetViewContainer.squareCropButton.isEnabled = !self.shouldShowLoader
                self.assetViewContainer.multipleSelectionButton.isEnabled = !self.shouldShowLoader
                self.assetViewContainer.spinnerIsShown = self.shouldShowLoader
                self.shouldShowLoader ? self.hideOverlayView() : ()
            }
        }
    }
    
    var onCameraTapped: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("Only code layout.")
    }

    // MARK: - Public Methods

    // MARK: Overlay view

    func hideOverlayView() {
        assetViewContainer.itemOverlay?.alpha = 0
    }

    // MARK: Loader and progress

    func fadeInLoader() {
        shouldShowLoader = true
        // Only show loader if full res image takes more than 0.5s to load.
        if #available(iOS 10.0, *) {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                if self.shouldShowLoader == true {
                    UIView.animate(withDuration: 0.2) {
                        self.assetViewContainer.spinnerView.alpha = 1
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            UIView.animate(withDuration: 0.2) {
                self.assetViewContainer.spinnerView.alpha = 1
            }
        }
    }

    func hideLoader() {
        shouldShowLoader = false
        assetViewContainer.spinnerView.alpha = 0
    }

    func updateProgress(_ progress: Float) {
        progressView.isHidden = progress > 0.99 || progress == 0
        progressView.progress = progress
        UIView.animate(withDuration: 0.1, animations: progressView.layoutIfNeeded)
    }

    // MARK: Crop Rect

    func currentCropRect() -> CGRect {
        let cropView = assetZoomableView
        let normalizedX = min(1, cropView.contentOffset.x &/ cropView.contentSize.width)
        let normalizedY = min(1, cropView.contentOffset.y &/ cropView.contentSize.height)
        let normalizedWidth = min(1, cropView.frame.width / cropView.contentSize.width)
        let normalizedHeight = min(1, cropView.frame.height / cropView.contentSize.height)
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }

    // MARK: Curtain

    func refreshImageCurtainAlpha() {
        let imageCurtainAlpha = abs(assetViewContainerConstraintTop?.constant ?? 0)
        / (assetViewContainer.frame.height - assetZoomableViewMinimalVisibleHeight)
        assetViewContainer.curtain.alpha = imageCurtainAlpha
    }

    func cellSize() -> CGSize {
        var screenWidth: CGFloat = UIScreen.main.bounds.width
        if UIDevice.current.userInterfaceIdiom == .pad && YPImagePickerConfiguration.widthOniPad > 0 {
            screenWidth =  YPImagePickerConfiguration.widthOniPad
        }
        let size = screenWidth / 4 * UIScreen.main.scale
        return CGSize(width: size, height: size)
    }

    // MARK: - Private Methods

    private func setupLayout() {
        subviews(
            collectionContainerView.subviews(
                collectionView
            ),
            line,
            galleryCameraView,
            assetViewContainer.subviews(
                assetZoomableView
            ),
            progressView,
            maxNumberWarningView.subviews(
                maxNumberWarningLabel
            )
        )

        collectionContainerView.fillContainer().left(16).right(16)
        collectionView.fillHorizontally().bottom(0)

        assetViewContainer.Bottom == line.Top
        line.height(1)
        line.fillHorizontally()

        assetViewContainer.top(0).fillHorizontally().heightEqualsWidth()
        self.assetViewContainerConstraintTop = assetViewContainer.topConstraint
        assetZoomableView.fillContainer().heightEqualsWidth()
        assetZoomableView.Bottom == galleryCameraView.Top - 4
        galleryCameraView.Bottom == collectionView.Top - 4
        galleryCameraView.fillHorizontally()
        assetViewContainer.sendSubviewToBack(assetZoomableView)

        progressView.height(5).fillHorizontally()
        progressView.Bottom == line.Top

        |maxNumberWarningView|.bottom(0)
        maxNumberWarningView.Top == safeAreaLayoutGuide.Bottom - 40
        maxNumberWarningLabel.centerHorizontally().top(11)
    }
    
    @objc
    private func cameraButtonTapped() {
        onCameraTapped?()
    }
}

public class ImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var onImageSelected: ((UIImage, URL) -> Void)?
    private var onVideoSelected: ((URL) -> Void)?
    private var onCancel: (() -> Void)?
    private let imagePicker = UIImagePickerController()
    
    public func presentPhotoLibrary(from: UIViewController, onImageSelected: @escaping ((UIImage, URL) -> Void), onCancel: (() -> Void)? = nil) {
        self.onImageSelected = onImageSelected
        self.onCancel = onCancel
        imagePicker.modalPresentationStyle = .fullScreen
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        if let videoExportPreset = YPImagePickerConfiguration.shared.videoExportPreset {
            imagePicker.videoExportPreset = videoExportPreset
        }
        from.present(imagePicker, animated: true, completion: nil)
    }
    
    public func presentCamera(from: UIViewController, mediaTypes: [String] = ["public.image", "public.movie"], onImageSelected: @escaping ((UIImage, URL) -> Void), onVideoSelected: ((URL) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onImageSelected = onImageSelected
        self.onVideoSelected = onVideoSelected
        self.onCancel = onCancel
        imagePicker.modalPresentationStyle = .fullScreen
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? mediaTypes
        imagePicker.sourceType = .camera
        if let videoQuality = YPImagePickerConfiguration.shared.imagePickerVideoQuality {
            imagePicker.videoQuality = videoQuality
        }
        if let videoExportPreset = YPImagePickerConfiguration.shared.videoExportPreset {
            imagePicker.videoExportPreset = videoExportPreset
        }
        from.present(imagePicker, animated: true, completion: nil)
    }
    
    public func dismiss() {
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onCancel?()
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            var imageUrl: URL?
            if picker.sourceType == UIImagePickerController.SourceType.camera {
                let imgName = "\(UUID().uuidString).jpeg"
                let documentDirectory = NSTemporaryDirectory()
                let localPath = documentDirectory.appending(imgName)
                
                let data = image.jpegData(compressionQuality: 0.3)! as NSData
                data.write(toFile: localPath, atomically: true)
                imageUrl = URL.init(fileURLWithPath: localPath)
            } else if let selectedImageUrl = info[UIImagePickerController.InfoKey.imageURL] as? URL {
                imageUrl = selectedImageUrl
            }
            guard let imageUrl = imageUrl else {
                return
            }

            onImageSelected?(image.keepOrientation(), imageUrl)
        } else if
            let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
              onVideoSelected?(url)
        }
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
}
extension UIImage {
    func keepOrientation() -> UIImage {
        if imageOrientation == UIImage.Orientation.up {
            return self
        }
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(origin: CGPoint.zero, size: size))
        let copy = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return copy ?? self
    }
}
