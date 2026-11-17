var clicks = 0;

document.getElementById("btn").onclick = function () {
    clicks = clicks + 1;
    document.getElementById("count").textContent = clicks;
}