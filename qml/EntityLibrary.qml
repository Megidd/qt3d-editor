/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the Qt3D Editor of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:GPL-EXCEPT$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3 as published by the Free Software
** Foundation with exceptions as appearing in the file LICENSE.GPL3-EXCEPT
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/
import QtQuick 2.5
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.1
import QtQml.Models 2.2

Item {
    id: entityLibrary

    property int gridMargin: 10
    property int buttonSize: 80
    property int optimalWidth: 2 * (buttonSize + gridMargin) + gridMargin
    property int splitHeight: entityViewHeader.height + 260

    signal createNewEntity(int entityType, int xPos, int yPos)

    Layout.minimumHeight: entityViewHeader.height
    height: splitHeight
    // Adjust width automatically for scrollbar, unless width has been adjusted manually
    width: ((gridRoot.cellHeight * (gridRoot.count / 2)) > entityView.height)
           ? optimalWidth + 21 : optimalWidth

    ButtonViewHeader {
        id: entityViewHeader
        headerText: qsTr("Shapes") + editorScene.emptyString
        tooltip: qsTr("Show/Hide Shapes View") + editorScene.emptyString
    }

    Rectangle {
        id: entityView
        anchors.top: entityViewHeader.bottom
        height: entityLibrary.height - entityViewHeader.height
        width: parent.width
        color: mainwindow.paneBackgroundColor
        border.color: mainwindow.viewBorderColor
        visible: entityViewHeader.viewVisible
        ScrollView {
            anchors.fill: parent
            anchors.leftMargin: gridMargin
            GridView {
                id: gridRoot
                clip: true
                topMargin: gridMargin
                cellHeight: buttonSize + gridMargin
                cellWidth: buttonSize + gridMargin
                model: EntityModel { id: entityModel }
                delegate: MouseArea {
                    id: delegateRoot
                    width: buttonSize
                    height: buttonSize

                    property int dragPositionX
                    property int dragPositionY

                    drag.target: dragEntityItem

                    onPressed: {
                        var globalPos = mapToItem(applicationArea, mouseX, mouseY)
                        dragPositionX = globalPos.x
                        dragPositionY = globalPos.y
                        dragEntityItem.startDrag(delegateRoot, meshDragImage,
                                                 "insertEntity", dragPositionX, dragPositionY,
                                                 meshType)
                        editorScene.showPlaceholderEntity("dragInsert", meshType)
                    }

                    onPositionChanged: {
                        var globalPos = mapToItem(applicationArea, mouseX, mouseY)
                        dragPositionX = globalPos.x
                        dragPositionY = globalPos.y
                        dragEntityItem.setPosition(dragPositionX, dragPositionY)
                        var scenePos = editorViewport.mapFromItem(applicationArea,
                                                                  dragPositionX,
                                                                  dragPositionY)
                        editorScene.movePlaceholderEntity("dragInsert",
                                    editorScene.getWorldPosition(scenePos.x, scenePos.y))
                    }

                    onReleased: {
                        var dropResult = dragEntityItem.endDrag(true)
                        editorScene.hidePlaceholderEntity("dragInsert")
                        // If no DropArea handled the drop, create new entity
                        if (dropResult === Qt.IgnoreAction) {
                            var scenePos = editorViewport.mapFromItem(applicationArea,
                                                                      dragPositionX,
                                                                      dragPositionY)
                            createNewEntity(meshType, scenePos.x, scenePos.y)
                        }
                    }

                    onCanceled: {
                        dragEntityItem.endDrag(false)
                        editorScene.hidePlaceholderEntity("dragInsert")
                    }

                    Rectangle {
                        id: entityButton
                        width: buttonSize
                        height: buttonSize
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: mainwindow.itemBackgroundColor
                        Column {
                            anchors.centerIn: parent
                            Image {
                                source: meshImage
                                width: 50
                                height: 50
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: meshString
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: mainwindow.textColor
                                font.family: mainwindow.labelFontFamily
                                font.weight: mainwindow.labelFontWeight
                                font.pixelSize: mainwindow.labelFontPixelSize
                            }
                        }
                    }
                }
            }
        }
    }
    Component.onCompleted: gridRoot.forceLayout()
}
