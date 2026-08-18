const copyButton = document.querySelector("[data-copy-contract]");
const contractValue = document.querySelector("#contract-value");
const copyStatus = document.querySelector("#copy-status");

copyButton?.addEventListener("click", async () => {
  if (!contractValue || !copyStatus) return;

  try {
    await navigator.clipboard.writeText(contractValue.textContent.trim());
    copyButton.lastChild.textContent = "Copied";
    copyStatus.textContent = "Contract address copied to clipboard.";
    window.setTimeout(() => {
      copyButton.lastChild.textContent = "Copy address";
      copyStatus.textContent = "";
    }, 2400);
  } catch {
    copyStatus.textContent = "Copy failed. Select the contract address manually.";
  }
});
