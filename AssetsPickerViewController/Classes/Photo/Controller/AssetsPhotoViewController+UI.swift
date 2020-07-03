//
//  AssetsPhotoViewController+UI.swift
//  AssetsPickerViewController
//
//  Created by DragonCherry on 2020/07/02.
//

import UIKit
import Photos

// MARK: - Internal APIs for UI
extension AssetsPhotoViewController {
    
    func updateEmptyView(count: Int) {
        let hasPermission = PHPhotoLibrary.authorizationStatus() == .authorized
        if hasPermission {
            if emptyView.isHidden {
                if count == 0 {
                    emptyView.isHidden = false
                }
            } else {
                if count > 0 {
                    emptyView.isHidden = true
                }
            }
        } else {
            emptyView.isHidden = true
        }
        logi("emptyView.isHidden: \(emptyView.isHidden), count: \(count)")
    }
    
    func updateNoPermissionView() {
        noPermissionView.isHidden = PHPhotoLibrary.authorizationStatus() == .authorized
        logi("isHidden: \(noPermissionView.isHidden)")
    }
    
    func updateLayout(layout: UICollectionViewLayout, isPortrait: Bool? = nil) {
        guard let flowLayout = layout as? UICollectionViewFlowLayout else { return }
        if let isPortrait = isPortrait {
            self.isPortrait = isPortrait
        }
        flowLayout.itemSize = self.isPortrait ? pickerConfig.assetPortraitCellSize(forViewSize: UIScreen.main.portraitContentSize) : pickerConfig.assetLandscapeCellSize(forViewSize: UIScreen.main.landscapeContentSize)
        flowLayout.minimumLineSpacing = self.isPortrait ? pickerConfig.assetPortraitLineSpace : pickerConfig.assetLandscapeLineSpace
        flowLayout.minimumInteritemSpacing = self.isPortrait ? pickerConfig.assetPortraitInteritemSpace : pickerConfig.assetLandscapeInteritemSpace
    }
    
    func setSelectedAssets(assets: [PHAsset]) {
        selectedArray.removeAll()
        selectedMap.removeAll()
        
        _ = assets.filter { AssetsManager.shared.isExist(asset: $0) }
            .map { [weak self] asset in
                guard let `self` = self else { return }
                self.selectedArray.append(asset)
                self.selectedMap.updateValue(asset, forKey: asset.localIdentifier)
        }
    }
    
    func updateSelectedCells() {
        guard selectedArray.isEmpty else { return }
        
        // initialize preselected assets
        selectedArray.forEach({ [weak self] (asset) in
            if let row = AssetsManager.shared.assetArray.firstIndex(of: asset) {
                let indexPathToSelect = IndexPath(row: row, section: 0)
                self?.select(at: indexPathToSelect)
//                self?.collectionView.selectItem(at: indexPathToSelect, animated: false, scrollPosition: .init())
//                self?.collectionView.collectionViewLayout.invalidateLayout()
            }
        })
        updateSelectionCount()
    }
    
    func select(album: PHAssetCollection) {
        loadingPlaceholderView.isHidden = false
        loadingActivityIndicatorView.startAnimating()
        AssetsManager.shared.selectAsync(album: album, completion: { [weak self] (result) in
            guard let `self` = self else { return }
            guard result else { return }
            self.updateNavigationStatus()
            self.collectionView.performBatchUpdates({ [weak self] in
                self?.collectionView.reloadData()
                self?.updateSelectedCells()
            }) { [weak self] (_) in
                self?.scrollToLastItemIfNeeded()
                self?.loadingPlaceholderView.isHidden = true
                self?.loadingActivityIndicatorView.stopAnimating()
            }
        })
    }
    
    func select(at indexPath: IndexPath) {
        let manager = AssetsManager.shared
        guard indexPath.row < manager.assetArray.count else { return }
        let asset = manager.assetArray[indexPath.row]
        if let _ = selectedMap[asset.localIdentifier] {} else {
            selectedArray.append(asset)
            selectedMap[asset.localIdentifier] = asset
        }
    }
    
    func updateCount(at indexPath: IndexPath) {
        // update selected UI
        guard var photoCell = collectionView.cellForItem(at: indexPath) as? AssetsPhotoCellProtocol else {
            logw("Invalid status.")
            return
        }
        photoCell.count = selectedArray.count
    }
    
    func deselect(asset: PHAsset, at indexPath: IndexPath) {
        guard let targetAsset = selectedMap[asset.localIdentifier] else {
            logw("Invalid status.")
            return
        }
        guard let targetIndex = selectedArray.firstIndex(of: targetAsset) else {
            logw("Invalid status.")
            return
        }
        selectedArray.remove(at: targetIndex)
        selectedMap.removeValue(forKey: targetAsset.localIdentifier)
        
        updateSelectionCount()
    }
    
    func scrollToLastItemIfNeeded() {
        let assets = AssetsManager.shared.assetArray
        guard !assets.isEmpty else { return }
        if pickerConfig.assetsIsScrollToBottom == true {
            self.collectionView.scrollToItem(at: IndexPath(row: assets.count - 1, section: 0), at: .bottom, animated: false)
        } else {
            self.collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .bottom, animated: false)
        }
    }
    
    func updateSelectionCount() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        for visibleIndexPath in visibleIndexPaths {
            guard AssetsManager.shared.assetArray.count > visibleIndexPath.row else {
                logw("Referred wrong index\(visibleIndexPath.row) while asset count is \(AssetsManager.shared.assetArray.count).")
                break
            }
            if let selectedAsset = selectedMap[AssetsManager.shared.assetArray[visibleIndexPath.row].localIdentifier], var photoCell = collectionView.cellForItem(at: visibleIndexPath) as? AssetsPhotoCellProtocol {
                if let selectedIndex = selectedArray.firstIndex(of: selectedAsset) {
                    photoCell.count = selectedIndex + 1
                }
            }
        }
    }
    
    func updateNavigationStatus() {
        
        if let album = AssetsManager.shared.selectedAlbum, selectedArray.isEmpty {
            title = self.title(forAlbum: album)
        } else {
            
            doneButtonItem.isEnabled = selectedArray.count >= (pickerConfig.assetsMinimumSelectionCount >= 0 ? pickerConfig.assetsMinimumSelectionCount : 1)
            
            let counts: (imageCount: Int, videoCount: Int) = selectedArray.reduce((0, 0)) { (result, asset) -> (Int, Int) in
                let imageCount = asset.mediaType == .image ? 1 : 0
                let videoCount = asset.mediaType == .video ? 1 : 0
                return (result.0 + imageCount, result.1 + videoCount)
            }
            
            let imageCount = counts.imageCount
            let videoCount = counts.videoCount
            
            var titleString: String = title(forAlbum: AssetsManager.shared.selectedAlbum)
            
            if imageCount > 0 && videoCount > 0 {
                titleString = String(format: String(key: "Title_Selected_Items"), NumberFormatter.decimalString(value: imageCount + videoCount))
            } else {
                if imageCount > 0 {
                    if imageCount > 1 {
                        titleString = String(format: String(key: "Title_Selected_Photos"), NumberFormatter.decimalString(value: imageCount))
                    } else {
                        titleString = String(format: String(key: "Title_Selected_Photo"), NumberFormatter.decimalString(value: imageCount))
                    }
                } else if videoCount > 0 {
                    if videoCount > 1 {
                        titleString = String(format: String(key: "Title_Selected_Videos"), NumberFormatter.decimalString(value: videoCount))
                    } else {
                        titleString = String(format: String(key: "Title_Selected_Video"), NumberFormatter.decimalString(value: videoCount))
                    }
                }
            }
            title = titleString
        }
    }
    
    func updateFooter() {
        guard let footerView = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter).last as? AssetsPhotoFooterView else {
            return
        }
        footerView.set(imageCount: AssetsManager.shared.count(ofType: .image), videoCount: AssetsManager.shared.count(ofType: .video))
    }
    
    func presentAlbumController(animated: Bool = true) {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }
        let controller = AssetsAlbumViewController(pickerConfig: self.pickerConfig)
        controller.delegate = self

        let navigationController = UINavigationController(rootViewController: controller)
        self.navigationController?.present(navigationController, animated: animated, completion: nil)
    }
    
    func title(forAlbum album: PHAssetCollection?) -> String {
        var titleString: String!
        if let albumTitle = album?.localizedTitle {
            titleString = "\(albumTitle) ▾"
        } else {
            titleString = ""
        }
        return titleString
    }
}
