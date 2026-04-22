import matplotlib.pyplot as plt
import networkx as nx

def visualize_network(model):
    G = nx.DiGraph()
    layers = list(model.children())

    previous_layer_size = None
    layer_nodes = []
    node_id = 0
    positions = {}

    for layer_index, layer in enumerate(layers):
        if isinstance(layer, nn.Linear):
            in_features = layer.in_features
            out_features = layer.out_features

            if previous_layer_size is None:
                input_nodes = []
                for i in range(in_features):
                    G.add_node(node_id)
                    positions[node_id] = (layer_index, -i)
                    input_nodes.append(node_id)
                    node_id += 1
                previous_layer_size = in_features
                layer_nodes.append(input_nodes)

            output_nodes = []
            for i in range(out_features):
                G.add_node(node_id)
                positions[node_id] = (layer_index + 1, -i)
                output_nodes.append(node_id)
                node_id += 1
            layer_nodes.append(output_nodes)


            for src in layer_nodes[-2]:
                for dst in layer_nodes[-1]:
                    G.add_edge(src, dst)
            previous_layer_size = out_features

    print("input nodes:" + str(layer_nodes[-2] ) )
    print("outputs nodes:" + str(layer_nodes[-1]) )

    plt.figure(figsize=(12, 6))
    nx.draw(G, pos=positions, with_labels=False, node_size=200, node_color="skyblue", edge_color="gray")
    plt.title("Neural Network Architecture (Policy Network)")
    plt.axis("off")
    plt.show()
