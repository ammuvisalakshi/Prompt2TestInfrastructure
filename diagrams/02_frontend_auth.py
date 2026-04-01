from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import CloudFront
from diagrams.aws.storage import S3
from diagrams.aws.security import Cognito
from diagrams.aws.general import Users
from diagrams.aws.network import APIGateway

with Diagram(
    "",
    show=False,
    filename="C:/MyProjects/AWS/Prompt2TestInfrastructure/diagrams/02_frontend_auth",
    direction="LR",
    outformat="png",
    graph_attr={
        "fontsize": "22",
        "bgcolor": "white",
        "fontcolor": "#232f3e",
        "pad": "1.0",
        "splines": "spline",
        "nodesep": "1.0",
        "ranksep": "2.5",
        "fontname": "Arial",
        "dpi": "150",
        "labelloc": "b",
        "label": "Frontend & Authentication",
    },
    node_attr={
        "fontsize": "12",
        "fontcolor": "#232f3e",
        "fontname": "Arial",
        "width": "1.5",
        "height": "1.5",
    },
    edge_attr={
        "penwidth": "2.0",
        "color": "#545b64",
        "arrowsize": "1.0",
    },
):
    users = Users("QA Engineers\n(Browser)")

    with Cluster("Frontend", graph_attr={"bgcolor": "#e6eef8", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        cf = CloudFront("CloudFront\nDistribution")
        s3 = S3("S3 Bucket\nReact SPA\n(Vite + Tailwind)")

    with Cluster("Authentication", graph_attr={"bgcolor": "#fef3e2", "pencolor": "#e8c877", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        cognito = Cognito("Cognito\nUser Pool +\nIdentity Pool")

    apigw = APIGateway("API Gateway\n(REST)")

    users >> Edge(color="#232f3e", style="solid", penwidth="2.5", label="HTTPS", fontsize="10", fontcolor="#545b64") >> cf
    cf >> Edge(color="#232f3e", style="solid", label="serves", fontsize="10", fontcolor="#545b64") >> s3
    users >> Edge(color="#b45309", style="dashed", label="sign-in / sign-up", fontsize="10", fontcolor="#b45309") >> cognito
    cognito >> Edge(color="#b45309", style="dashed", label="JWT token", fontsize="10", fontcolor="#b45309") >> apigw
    cf >> Edge(color="#232f3e", style="solid", label="proxies API calls", fontsize="10", fontcolor="#545b64") >> apigw
