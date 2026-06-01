//
//  AppTabBarController.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/28.
//

import UIKit

final class AppTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupViewControllers()
    }

    private func setupViewControllers() {
        let homeNavigationController = UINavigationController(rootViewController: HomeViewViewController())
        homeNavigationController.tabBarItem = UITabBarItem(
            title: "首页",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        let settingsNavigationController = UINavigationController(rootViewController: SettingsViewController())
        settingsNavigationController.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        viewControllers = [
            homeNavigationController,
            settingsNavigationController
        ]
    }

    private func setupAppearance() {
        tabBar.tintColor = Theme.audioBlue
        tabBar.unselectedItemTintColor = Theme.pageSecondaryText

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.navigationBarBackground
        appearance.shadowColor = Theme.pageControlBorder

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
