//
//  BoardViewController.swift
//  Whiteboard
//
//  Created by Andrew on 2017-11-15.
//  Copyright © 2017 hearthedge. All rights reserved.
//

import UIKit
import RxSwift
import MultipeerConnectivity

class LineFormatSettings {
    static let sharedInstance = LineFormatSettings()
    
    var width : CGFloat = 5.0
    var cap = CGLineCap.round
    //var cap = CGLineCap.square
    var color = LineColor.blue
}

class BoardViewController: UIViewController, MCBrowserViewControllerDelegate, CloseMenu, UIScrollViewDelegate {
    
    //MARK: Properties / Outlets
    let viewModel = BoardViewModel()
    let disposeBag = DisposeBag()
    var mpcHandler = MPCHandler.sharedInstance
    
    @IBOutlet var ThicknessButtons: [UIButton]!
    @IBOutlet weak var content: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var SettingsMenuButton: UIButton!
    @IBOutlet weak var MainMenuButton: UIButton!
    @IBOutlet weak var MainMenuHeight: NSLayoutConstraint!
    @IBOutlet weak var SettingsMenuHeight: NSLayoutConstraint!
    @IBOutlet weak var drawView: DrawView!
    @IBOutlet weak var lineImageView: UIImageView!
    @IBOutlet var ColorButtons: [UIButton]!
    
    //MARK: Load
    override func viewDidLoad() {
        super.viewDidLoad()
        updateColorButtons()
        updateThicknessButtons()
        setUpModel()
        setUpMenus()
        setUpScrollView()
    }
    
    //MARK:Setup
    func updateThicknessButtons(){
        let formatLine = LineFormatSettings.sharedInstance
        for button in ThicknessButtons {
            button.setTitleColor(LineElement(line: Line(), width: 0, cap: .butt, color: formatLine.color).drawColor, for: UIControlState.normal) //Janky-jank
        }
    }
    func setUpScrollView(){
        self.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2;
        self.scrollView.maximumZoomScale = 4.0
        self.scrollView.contentSize = CGSize(width: 2000, height: 2000)
        self.scrollView.delaysContentTouches = false
        self.scrollView.canCancelContentTouches = true
        if self.view.frame.size.width < self.view.frame.size.height{
            self.scrollView.minimumZoomScale = self.view.frame.size.width / 2000
        } else {
            self.scrollView.minimumZoomScale = self.view.frame.size.height / 2000
        }
    }
    func updateColorButtons(){
        for button in ColorButtons{
            button.backgroundColor = LineElement(line: Line(), width: 69.69, cap: .butt, color: LineColor(rawValue: button.tag)!).drawColor //sooo janky
        }
    }
    func setUpModel(){
        self.drawView.closeMenuDelagate = self
        self.drawView.clearsContextBeforeDrawing = true
        self.drawView.viewModel = self.viewModel
        
        self.viewModel.recieveLine(self.drawView.lineStream)
        
        self.viewModel.lineImage.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { lineImage in
                self.lineImageView.image = lineImage
//                UIView.transition(with: self.view,
//                                  duration: 0,
//                                  options: UIViewAnimationOptions.transitionCrossDissolve,
//                                  animations: {  },
//                                  completion: nil)
            }).disposed(by: disposeBag)
    }
    func setUpMenus(){
        MainMenuButton.setTitleColor(LineElement(line: Line(), width: 0, cap: .butt, color: LineFormatSettings.sharedInstance.color).drawColor, for: UIControlState.normal) //jankness
        MainMenuButton.titleLabel?.font = MainMenuButton.titleLabel?.font.withSize(40.0)
        MainMenuHeight.constant = -120
        
        SettingsMenuHeight.constant = -76
    }
    
    //MARK: Actions
    
    @IBAction func thickness(_ sender: UIButton) {
        let formatLine = LineFormatSettings.sharedInstance
        switch sender.tag{
        case 0:
            formatLine.width = 4.0
            MainMenuButton.titleLabel?.font = MainMenuButton.titleLabel?.font.withSize(15.0)
            break
        case 1:
            formatLine.width = 8.0
            MainMenuButton.titleLabel?.font = MainMenuButton.titleLabel?.font.withSize(24.0)
            break
        case 2:
            formatLine.width = 16.0
            MainMenuButton.titleLabel?.font = MainMenuButton.titleLabel?.font.withSize(33.0)
            break
        case 3:
            formatLine.width = 32.0
            MainMenuButton.titleLabel?.font = MainMenuButton.titleLabel?.font.withSize(42.0)
            break
        default:
            formatLine.width = 64.0
            MainMenuButton.titleLabel?.font = MainMenuButton.titleLabel?.font.withSize(51.0)
            break
        }
    }
    
    @IBAction func color(_ sender: UIButton) {
        let formatLine = LineFormatSettings.sharedInstance
        switch sender.tag{
        case 0:
            formatLine.color = LineColor.black
        case 1:
            formatLine.color = LineColor.white
        case 2:
            formatLine.color = LineColor.red
        case 3:
            formatLine.color = LineColor.orange
        case 4:
            formatLine.color = LineColor.yellow
        case 5:
            formatLine.color = LineColor.green
        case 6:
            formatLine.color = LineColor.blue
        case 7:
            formatLine.color = LineColor.purple
        default:
            formatLine.color = LineColor.black
        }
        MainMenuButton.setTitleColor(LineElement(line: Line(), width: 0, cap: .butt, color: formatLine.color).drawColor, for: UIControlState.normal) //jankness
        updateThicknessButtons()
    }
    
    @IBAction func Share(_ sender: UIButton) {
        if let image = snapshot(of: lineImageView) {
            let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
                
            }
            
            self.present(activityViewController, animated: true)
            
        }
        Settings(sender)
    }
    @IBAction func Clear(_ sender: UIButton) {
        let alert = UIAlertController(title: "Clear", message: "Are you sure you want to clear the canvas?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil))
        alert.addAction(UIAlertAction(title: "Clear", style: UIAlertActionStyle.destructive, handler: {action in
            InstructionManager.sharedInstance.resetInstructionStore()
            self.viewModel.clear()
        }))
        self.present(alert, animated: true, completion: nil)
        Settings(sender)
    }
    @IBAction func Add(_ sender: Any) {
        if mpcHandler.session != nil{
            mpcHandler.setupBrowser()
            mpcHandler.browser.delegate = self
            self.present(mpcHandler.browser, animated: true, completion: nil)
        }
        Settings(sender)
    }
    
    @IBAction func Settings(_ sender: Any) {
        if SettingsMenuHeight.constant == -76{
            UIView.animate(withDuration: 0.5, animations: {
                self.SettingsMenuHeight.constant = 0
                self.SettingsMenuButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
                self.view.layoutIfNeeded()
            })
        } else {
            UIView.animate(withDuration: 0.4, animations: {
                self.SettingsMenuHeight.constant = -76
                self.SettingsMenuButton.transform = CGAffineTransform(rotationAngle: 0)
                self.view.layoutIfNeeded()
            })
        }
    }
    @IBAction func Menu(_ sender: UIButton) {
        
        if MainMenuHeight.constant == -120{
            UIView.animate(withDuration: 0.5, animations: {
                self.MainMenuHeight.constant = 0
                self.MainMenuButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
                self.view.layoutIfNeeded()
            })
        } else {
            closeMenu()
        }
    }
    
    //MARK: Close Menu Delegate
    func closeMenu() {
        UIView.animate(withDuration: 0.4, animations: {
            self.MainMenuHeight.constant = -120
            self.MainMenuButton.transform = CGAffineTransform(rotationAngle: 0)
            self.view.layoutIfNeeded()
        })
    }

    //MARK: Browser View Controller Delegate
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        mpcHandler.browser.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        mpcHandler.browser.dismiss(animated: true, completion: nil)
    }

    //MARK: ScrollView
    func viewForZooming(in scrollView: UIScrollView) -> UIView?{
        return content
    }
    
    //MARK: Save Image
    private func snapshot(of view:UIView) -> UIImage? {
        UIGraphicsBeginImageContext(view.bounds.size)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return snapshot
    }
}
