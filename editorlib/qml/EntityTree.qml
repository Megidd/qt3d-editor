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
import com.theqtcompany.SceneEditor3D 1.0
import QtQuick.Controls.Styles 1.4

Item {
    id: treeViewSplit

    property bool entityTreeViewEditing: entityTreeView.editing

    property alias view: entityTreeView
    property alias menu: addComponentMenu
    property bool multiSelect: false
    property bool multiSelectedCamera: false

    Keys.onDeletePressed: {
        // Doublecheck that we don't try to remove the scene root
        if (entityTreeView.selection.currentIndex !== editorScene.sceneModel.sceneEntityIndex())
            editorScene.undoHandler.createRemoveEntityCommand(selectedEntityName)
    }

    function focusTree() {
        entityTreeView.forceActiveFocus(Qt.MouseFocusReason)
    }

    function selectSceneRoot() {
        entityTreeView.selection.setCurrentIndex(
                    editorScene.sceneModel.sceneEntityIndex(),
                    ItemSelectionModel.SelectCurrent)
        entityTreeView.expand(entityTreeView.selection.currentIndex)
    }

    function addNewEntity(entityType, xPos, yPos) {
        var x = xPos ? xPos : -1
        var y = yPos ? yPos : -1
        entityTreeView.editing = false

        // Never allow inserting to root
        if (entityTreeView.selection.currentIndex.row === -1)
            selectSceneRoot()
        editorScene.undoHandler.createInsertEntityCommand(entityType, selectedEntityName,
                                                          editorScene.getWorldPosition(x, y))
        var newItemIndex = editorScene.sceneModel.lastInsertedIndex()

        entityTreeView.expand(entityTreeView.selection.currentIndex)
        entityTreeView.selection.setCurrentIndex(newItemIndex,
                                                 ItemSelectionModel.SelectCurrent)
        // Remove focus so activating editing will always force it on
        entityTreeView.focus = true
    }

    Component.onCompleted: selectSceneRoot()

    property int splitHeight: treeViewHeader.height + 130

    Layout.minimumHeight: treeViewHeader.height
    height: splitHeight

    ButtonViewHeader {
        id: treeViewHeader
        anchors.top: treeViewSplit.top
        headerText: qsTr("Scene") + editorScene.emptyString
        tooltip: qsTr("Show/Hide Scene View") + editorScene.emptyString

        onShowViewButtonPressed: {
            treeViewSplit.height = splitHeight
        }
        onHideViewButtonPressed: {
            splitHeight = treeViewSplit.height
            treeViewSplit.height = minimumHeaderHeight
        }
    }

    TreeView {
        id: entityTreeView
        anchors.top: treeViewHeader.bottom
        anchors.bottom: treeViewSplit.bottom
        width: parent.width
        visible: treeViewHeader.viewVisible
        model: editorScene.sceneModel
        selectionMode: SelectionMode.ExtendedSelection
        selection: ItemSelectionModel {
            model: editorScene.sceneModel
        }
        headerVisible: false
        alternatingRowColors: false
        backgroundVisible: false
        style: TreeViewStyle {
            textColor: mainwindow.textColor
            highlightedTextColor: mainwindow.textColor
            backgroundColor: mainwindow.paneBackgroundColor
            alternateBackgroundColor: mainwindow.paneBackgroundColor
        }

        property bool editing: false
        property bool sceneRootSelected: true
        property bool cameraSelected: true
        property bool groupSelected: true

        onExpanded: {
            model.addExpandedItem(index)
        }
        onCollapsed: {
            model.removeExpandedItem(index)
        }

        Connections {
            target: editorScene.sceneModel
            onExpandItems: {
                for (var i = 0; i < items.length; i++)
                    entityTreeView.expand(items[i])
            }
            onSelectIndex: {
                entityTreeView.selection.setCurrentIndex(selectIndex,
                                                         ItemSelectionModel.SelectCurrent)
            }
        }

        itemDelegate: FocusScope {
            MouseArea {
                id: treeItemMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                property int dragPositionX
                property int dragPositionY
                drag.target: dragEntityItem

                function startDrag() {
                    var globalPos = mapToItem(applicationArea, mouseX, mouseY)
                    dragPositionX = globalPos.x
                    dragPositionY = globalPos.y
                    var meshType
                    var meshDragImage
                    var itemType = editorScene.sceneModel.editorSceneItemFromIndex(
                                styleData.index).itemType();
                    if (styleData.index === editorScene.sceneModel.sceneEntityIndex()
                            || itemType === EditorSceneItem.Camera
                            || itemType === EditorSceneItem.SceneLoader) {
                        // TODO: SceneLoader blocked because it currently crashes, and also
                        // TODO: because it cannot be safely deleted, which is needed when
                        // TODO: reparenting, which does duplicate+delete (QTBUG-52723).
                        meshType = EditorUtils.InvalidEntity
                        // TODO: make a proper "invalid drag" icon
                        meshDragImage = "images/cross.png"
                    } else if (itemType === EditorSceneItem.Light) {
                        meshType = EditorUtils.LightEntity
                        meshDragImage = "images/mesh_light_large.png"
                    } else if (itemType === EditorSceneItem.Group) {
                        meshType = EditorUtils.GroupEntity
                        meshDragImage = "images/mesh_group_large.png"
                    } else {
                        // Use cuboid type to indicate mesh
                        meshType = EditorUtils.CuboidEntity
                        meshDragImage = "images/mesh_large.png"
                    }

                    dragEntityItem.startDrag(treeItemMouseArea, meshDragImage,
                                             "changeParent", dragPositionX, dragPositionY,
                                             meshType, 0.3,
                                             editorScene.sceneModel.entityName(styleData.index))
                }

                onPressed: {
                    if (mouse.modifiers & Qt.ControlModifier) {
                        // Handle multiselection
                        editorScene.addToMultiSelection(editorScene.sceneModel.entityName(
                                                            styleData.index))
                        // If empty list, select scene root
                        if (selectionList.length === 0) {
                            selectedEntityName = ""
                            selectSceneRoot()
                        }
                    } else {
                        // Clear selectionList
                        selectionList.length = 0
                        editorScene.multiSelection = selectionList
                        // Deselect if clicked is already selected
                        if (editorScene.previousSelectedEntityName()
                                === editorScene.sceneModel.entityName(styleData.index)) {
                            entityTreeView.selection.select(styleData.index,
                                                            ItemSelectionModel.Toggle)
                            // Handle deselection
                            if (!entityTreeView.selection.selectedIndexes.length) {
                                selectedEntityName = ""
                                selectSceneRoot()
                            }
                        } else {
                            entityTreeView.selection.setCurrentIndex(styleData.index,
                                                                     ItemSelectionModel.SelectCurrent)
                        }
                    }
                    entityTreeView.expand(styleData.index)
                }

                onPositionChanged: {
                    if (!dragEntityItem.Drag.active) {
                        startDrag()
                    } else {
                        var globalPos = mapToItem(applicationArea, mouseX, mouseY)
                        dragPositionX = globalPos.x
                        dragPositionY = globalPos.y
                        dragEntityItem.setPosition(dragPositionX, dragPositionY)
                        entityTreeView.expand(styleData.index)
                    }
                }

                onReleased: {
                    var dropResult = dragEntityItem.endDrag(true)
                }

                onCanceled: {
                    dragEntityItem.endDrag(false)
                }

                onDoubleClicked: {
                    entityTreeView.editing = true
                }
            }
            DropArea {
                anchors.fill: parent
                keys: [ "insertEntity", "changeParent" ]

                function isValidDropTarget(dropSource) {
                    // Dropping into camera is always invalid
                    // Camera can only be dropped into scene root
                    // Light can only be dropped to light or transform entity
                    // Group entities cannot be dropped under non-group entities
                    var itemType = editorScene.sceneModel.editorSceneItemFromIndex(
                                styleData.index).itemType();
                    var dropValid =
                            dropSource.drag.target.entityType !== EditorUtils.InvalidEntity
                            && itemType !== EditorSceneItem.Camera
                            && (dropSource.drag.target.entityType !== EditorUtils.LightEntity
                                || itemType === EditorSceneItem.Light
                                || itemType === EditorSceneItem.Group)
                            && (styleData.index === editorScene.sceneModel.sceneEntityIndex()
                                || dropSource.drag.target.entityType !== EditorUtils.CameraEntity)
                            && (dropSource.drag.target.entityType !== EditorUtils.GroupEntity
                                || itemType === EditorSceneItem.Group
                                || styleData.index === editorScene.sceneModel.sceneEntityIndex())
                    if (dropValid && dropSource.drag.target.dragKey === "changeParent") {
                        dropValid = editorScene.sceneModel.canReparent(
                                    editorScene.sceneModel.editorSceneItemFromIndex(styleData.index),
                                    editorScene.sceneModel.editorSceneItemFromIndex(
                                        editorScene.sceneModel.getModelIndexByName(dropSource.drag.target.entityName)))
                    }

                    return dropValid
                }

                onDropped: {
                    if (isValidDropTarget(drop.source)) {
                        dragHighlight.visible = false
                        entityTreeView.selection.setCurrentIndex(styleData.index,
                                                                 ItemSelectionModel.SelectCurrent)
                        if (drop.source.drag.target.dragKey === "changeParent") {
                            var entityName = editorScene.sceneModel.entityName(styleData.index)
                            editorScene.undoHandler.createReparentEntityCommand(
                                        entityName,
                                        drag.source.drag.target.entityName)
                            drop.action = Qt.MoveAction
                            entityTreeView.expand(
                                        editorScene.sceneModel.getModelIndexByName(entityName))
                        } else {
                            entityTree.addNewEntity(drag.source.drag.target.entityType)
                            drop.action = Qt.CopyAction
                        }
                        drop.accept()
                    }
                }
                onEntered: {
                    if (isValidDropTarget(drag.source)) {
                        dragHighlight.visible = true
                        if (drag.source.drag.target.dragKey === "changeParent")
                            dragEntityItem.opacity = 1
                    }
                }
                onExited: {
                    dragHighlight.visible = false
                    if (drag.source.drag.target.dragKey === "changeParent")
                        dragEntityItem.opacity = 0.3
                }

                Rectangle {
                    id: dragHighlight
                    anchors.fill: parent
                    color: mainwindow.selectionColor
                    visible: false
                }
            }

            Text {
                id: valueField
                anchors.verticalCenter: parent.verticalCenter
                color: mainwindow.textColor
                elide: styleData.elideMode
                text: styleData.value
                visible: !entityTreeView.editing || !styleData.selected
                anchors.fill: parent
                clip: true
            }
            Rectangle {
                id: renameField
                anchors.fill: parent
                color: mainwindow.paneBackgroundColor
                border.color: mainwindow.listHighlightColor
                visible: !valueField.visible
                TextInput {
                    id: renameTextiInput
                    anchors.fill: parent
                    clip: true
                    visible: !valueField.visible
                    selectByMouse: true
                    focus: true
                    color: mainwindow.textColor
                    selectionColor: mainwindow.selectionColor
                    selectedTextColor: mainwindow.textColor
                    font.family: mainwindow.labelFontFamily
                    font.weight: mainwindow.labelFontWeight
                    font.pixelSize: mainwindow.labelFontPixelSize
                    validator: RegExpValidator {
                        regExp: /^[A-Za-z_][A-Za-z0-9_ ]*$/
                    }

                    onVisibleChanged: {
                        if (visible) {
                            text = styleData.value
                            selectAll()
                            forceActiveFocus(Qt.MouseFocusReason)
                        }
                    }

                    onCursorVisibleChanged: {
                        if (!cursorVisible)
                            entityTreeView.editing = false
                    }

                    Keys.onReturnPressed: {
                        entityTreeView.editing = false
                        if (text !== model.name) {
                            editorScene.undoHandler.createRenameEntityCommand(selectedEntityName,
                                                                              text)
                        }
                        selectedEntityName = editorScene.sceneModel.entityName(
                                    entityTreeView.selection.currentIndex)
                    }
                }
            }
        }
        onDoubleClicked: {
            entityTreeView.editing = true
        }

        TableViewColumn {
            title: qsTr("Entities") + editorScene.emptyString
            role: "name"
            width: parent.width - 50
        }
        TableViewColumn {
            title: qsTr("Visibility") + editorScene.emptyString
            role: "visibility"
            width: 18
            delegate: VisiblePropertyInputField {
                id: visibleProperty
                component: editorScene.sceneModel.editorSceneItemFromIndex(styleData.index).entity()
                propertyName: "enabled"
                visibleOnImage: "images/visible_on.png"
                visibleOffImage: "images/visible_off.png"
                // The component is not shown for root item
                visible: (styleData.index !== editorScene.sceneModel.sceneEntityIndex()) ? true
                                                                                         : false

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        entityName = editorScene.sceneModel.entityName(styleData.index)
                        if (entityEnabled)
                            entityEnabled = false
                        else
                            entityEnabled = true
                        visibleProperty.visibleImageClicked()
                    }
                }
            }
        }

        Connections {
            target: entityTreeView.selection
            onCurrentIndexChanged: {
                entityTreeView.editing = false
                // If there is no current item selected for some reason, fall back to scene root
                // TODO: Causes unwanted behavior with multiselection. Find out why before taking back into use.
                /*if (entityTreeView.selection.currentIndex.row === -1) {
                    selectedEntityName = ""
                    selectSceneRoot()
                } else*/ {
                    entityTreeView.sceneRootSelected =
                            (editorScene.sceneModel.sceneEntityIndex() === entityTreeView.selection.currentIndex)
                    selectedEntity = editorScene.sceneModel.editorSceneItemFromIndex(entityTreeView.selection.currentIndex)
                    if (selectedEntity) {
                        componentPropertiesView.model = selectedEntity.componentsModel
                        entityTreeView.cameraSelected =
                                selectedEntity.itemType() === EditorSceneItem.Camera
                        entityTreeView.groupSelected =
                                selectedEntity.itemType() === EditorSceneItem.Group
                        selectedEntityName = editorScene.sceneModel.entityName(
                                    entityTreeView.selection.currentIndex)
                        // Don't clear selection boxes if there are items in multiselection list
                        if (!selectionList.length) {
                            editorScene.clearSelectionBoxes()
                            selectedEntity.showSelectionBox = true
                        }
                    } else {
                        // Should never get here
                        selectedEntityName = ""
                        editorScene.clearSelectionBoxes()
                    }
                    editorScene.selection = selectedEntity.entity()
                }
            }
        }

        ComponentMenu {
            id: addComponentMenu
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: {
                // Prevent menu popup if no entity is selected
                if (componentPropertiesView.model !== undefined)
                    addComponentMenu.popup()
            }
        }
    }
}
