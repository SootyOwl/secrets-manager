import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

Kirigami.ApplicationWindow {
    id: root

    title: "Secrets"
    width: Kirigami.Units.gridUnit * 30
    height: Kirigami.Units.gridUnit * 44
    minimumWidth: Kirigami.Units.gridUnit * 20
    minimumHeight: Kirigami.Units.gridUnit * 20

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn

    // Pick up changes made in KWallet Manager or by hand.
    onActiveChanged: if (active) backend.refresh()

    pageStack.initialPage: FormCard.FormCardPage {
        title: "Secrets"

        actions: [
            Kirigami.Action {
                text: "Add Secret"
                icon.name: "list-add"
                onTriggered: secretDialog.openFor("")
            },
            Kirigami.Action {
                text: "Link to Program"
                icon.name: "link"
                enabled: backend.secretNames.length > 0
                onTriggered: linkDialog.openFor(null)
            },
            Kirigami.Action {
                text: "Open KWallet Manager"
                icon.name: "kwalletmanager"
                displayHint: Kirigami.DisplayHint.AlwaysHide
                onTriggered: {
                    const err = backend.openWallet()
                    if (err)
                        root.showPassiveNotification(err)
                }
            },
            Kirigami.Action {
                text: "Refresh"
                icon.name: "view-refresh"
                displayHint: Kirigami.DisplayHint.AlwaysHide
                onTriggered: backend.refresh()
            }
        ]

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            visible: backend.loadError.length > 0
            type: Kirigami.MessageType.Error
            text: backend.loadError
        }

        FormCard.FormHeader {
            title: "Stored secrets"
        }

        FormCard.FormCard {
            Repeater {
                model: backend.secrets

                delegate: ColumnLayout {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 0

                    FormCard.FormDelegateSeparator { visible: index > 0 }

                    CardRow {
                        iconName: "lock"
                        title: modelData.name
                        subtitle: modelData.usedBy ? "Used by " + modelData.usedBy : "Not linked to a program"
                        onClicked: secretDialog.openFor(modelData.name)

                        QQC2.ToolButton {
                            text: "Change value"
                            icon.name: "document-edit"
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: secretDialog.openFor(modelData.name)
                        }
                        QQC2.ToolButton {
                            text: "Delete"
                            icon.name: "edit-delete"
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: deleteDialog.openFor(modelData)
                        }
                    }
                }
            }

            FormCard.FormDelegateSeparator { visible: backend.secrets.length > 0 }

            FormCard.FormButtonDelegate {
                icon.name: "list-add"
                text: "Add a secret…"
                description: backend.secrets.length === 0 ? "API keys and tokens are kept in your KDE Wallet" : ""
                onClicked: secretDialog.openFor("")
            }
        }

        FormCard.FormHeader {
            title: "Linked programs"
        }

        FormCard.FormCard {
            Repeater {
                model: backend.links

                delegate: ColumnLayout {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 0

                    FormCard.FormDelegateSeparator { visible: index > 0 }

                    CardRow {
                        iconName: modelData.missing ? "data-warning" : "utilities-terminal"
                        title: modelData.program
                        subtitle: modelData.missing
                            ? "$" + modelData.variable + " ← “" + modelData.secret + "” no longer exists"
                            : "$" + modelData.variable + " ← " + modelData.secret
                        warning: modelData.missing
                        onClicked: linkDialog.openFor(modelData)

                        QQC2.ToolButton {
                            text: "Unlink"
                            icon.name: "remove-link"
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                backend.removeLink(modelData.program, modelData.variable)
                                root.showPassiveNotification("Unlinked " + modelData.program)
                            }
                        }
                    }
                }
            }

            FormCard.FormDelegateSeparator { visible: backend.links.length > 0 }

            FormCard.FormButtonDelegate {
                icon.name: "link"
                text: "Link a secret to a program…"
                enabled: backend.secretNames.length > 0
                description: enabled ? "" : "Add a secret first"
                onClicked: linkDialog.openFor(null)
            }
        }

        FormCard.FormSectionText {
            text: "Typing a linked program's name in a terminal starts it with its secrets set; "
                + "your shell never holds them. Changes apply to terminals opened afterwards."
        }
    }

    // A card row: icon, two lines of text, then any trailing buttons given as children.
    component CardRow: FormCard.AbstractFormDelegate {
        id: row

        property string iconName
        property string title
        property string subtitle
        property bool warning: false
        default property alias trailing: trailingRow.data

        Layout.fillWidth: true

        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: row.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    text: row.title
                    elide: Text.ElideRight
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: row.subtitle
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    color: row.warning ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                }
            }

            RowLayout {
                id: trailingRow
                spacing: 0
            }
        }
    }

    Kirigami.Dialog {
        id: secretDialog
        objectName: "secretDialog"

        property string editing: ""
        readonly property bool nameValid: backend.validName(nameField.text)
        readonly property bool canSave: nameValid && valueField.text.length > 0

        function openFor(name) {
            editing = name
            nameField.text = name
            valueField.text = ""
            saveError.visible = false
            open()
            if (name)
                valueField.forceActiveFocus()
            else
                nameField.forceActiveFocus()
        }

        function save() {
            if (!canSave)
                return
            const err = backend.storeSecret(nameField.text, valueField.text)
            valueField.text = ""
            if (err) {
                saveError.text = err
                saveError.visible = true
                return
            }
            close()
            root.showPassiveNotification("Saved “" + nameField.text + "”")
        }

        title: editing ? "Change “" + editing + "”" : "Add Secret"
        preferredWidth: Kirigami.Units.gridUnit * 22
        padding: Kirigami.Units.largeSpacing
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: "Save"
                icon.name: "document-save"
                enabled: secretDialog.canSave
                onTriggered: secretDialog.save()
            }
        ]
        onClosed: valueField.text = ""

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.TextField {
                    id: nameField
                    Kirigami.FormData.label: "Name:"
                    placeholderText: "e.g. openrouter"
                    readOnly: secretDialog.editing.length > 0
                    onAccepted: valueField.forceActiveFocus()
                }
                Kirigami.PasswordField {
                    id: valueField
                    Kirigami.FormData.label: "Value:"
                    placeholderText: "Paste the key or token"
                    onAccepted: secretDialog.save()
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: nameField.text.length > 0 && !secretDialog.nameValid
                type: Kirigami.MessageType.Error
                text: "Use only letters, digits, “.”, “_” or “-”."
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !secretDialog.editing && secretDialog.nameValid && backend.exists(nameField.text)
                type: Kirigami.MessageType.Warning
                text: "“" + nameField.text + "” already exists. Saving replaces its value."
            }
            Kirigami.InlineMessage {
                id: saveError
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
            }
        }
    }

    Kirigami.Dialog {
        id: linkDialog
        objectName: "linkDialog"

        property var original: null
        property bool variableEdited: false
        readonly property bool programValid: backend.validName(programField.text)
        readonly property bool variableValid: backend.validVariable(variableField.text)

        function openFor(link) {
            original = link
            variableEdited = !!link
            programField.text = link ? link.program : ""
            secretBox.currentIndex = link ? Math.max(0, secretBox.find(link.secret)) : 0
            variableField.text = link ? link.variable : backend.suggestVariable(secretBox.currentText)
            linkError.visible = false
            open()
            programField.forceActiveFocus()
        }

        function save() {
            if (!programValid || !variableValid)
                return
            const err = backend.saveLink(secretBox.currentText, programField.text, variableField.text,
                                         original ? original.program : "", original ? original.variable : "")
            if (err) {
                linkError.text = err
                linkError.visible = true
                return
            }
            close()
            root.showPassiveNotification("Linked " + programField.text)
        }

        title: original ? "Edit Link" : "Link Secret to Program"
        preferredWidth: Kirigami.Units.gridUnit * 24
        padding: Kirigami.Units.largeSpacing
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: "Save"
                icon.name: "link"
                enabled: linkDialog.programValid && linkDialog.variableValid
                onTriggered: linkDialog.save()
            }
        ]

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.TextField {
                    id: programField
                    Kirigami.FormData.label: "Program:"
                    placeholderText: "Command name, e.g. borealis"
                    onAccepted: linkDialog.save()
                }
                QQC2.ComboBox {
                    id: secretBox
                    Kirigami.FormData.label: "Secret:"
                    model: backend.secretNames
                    onActivated: if (!linkDialog.variableEdited)
                        variableField.text = backend.suggestVariable(currentText)
                }
                QQC2.TextField {
                    id: variableField
                    Kirigami.FormData.label: "As variable:"
                    font.family: "monospace"
                    onTextEdited: linkDialog.variableEdited = true
                    onAccepted: linkDialog.save()
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: programField.text.length > 0 && !linkDialog.programValid
                type: Kirigami.MessageType.Error
                text: "Enter just the command name, without arguments or a path."
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: linkDialog.programValid && !backend.onPath(programField.text)
                type: Kirigami.MessageType.Information
                text: "“" + programField.text + "” isn't installed on the host. "
                    + "That's fine if it only exists in a container."
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: variableField.text.length > 0 && !linkDialog.variableValid
                type: Kirigami.MessageType.Error
                text: "Variable names use letters, digits and “_”, and can't start with a digit."
            }
            Kirigami.InlineMessage {
                id: linkError
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
            }
        }
    }

    Kirigami.PromptDialog {
        id: deleteDialog
        objectName: "deleteDialog"

        property var secret: null

        function openFor(s) {
            secret = s
            open()
        }

        title: secret ? "Delete “" + secret.name + "”?" : ""
        subtitle: secret && secret.usedBy
            ? "It will also be unlinked from " + secret.usedBy + ". This can't be undone."
            : "This can't be undone."
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: "Delete"
                icon.name: "edit-delete"
                onTriggered: {
                    const name = deleteDialog.secret.name
                    const err = backend.deleteSecret(name)
                    deleteDialog.close()
                    root.showPassiveNotification(err ? err : "Deleted “" + name + "”")
                }
            }
        ]
    }
}
